package com.vigiaia.app

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.*
import com.minhacamera.PhoneCameraBackgroundService
import com.minhacamera.PhoneStreamDiagnostics
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** Bounded local recorder; no image/audio capture, network upload or per-frame disk I/O. */
internal object AppDiagnostics {
    private val worker = Executors.newSingleThreadScheduledExecutor { Thread(it, "vigia-diagnostics") }
    private val main = Handler(Looper.getMainLooper())
    private lateinit var app: Application
    private val events = ArrayDeque<JSONObject>()
    private val samples = ArrayDeque<JSONObject>()
    private var incidents = JSONArray()
    private var previous = JSONObject()
    private var lastExit = JSONObject()
    private var startedAt = 0L
    private var session = ""
    private var unhandled = false
    private var recoveryNeedsSaving = false
    private var persistenceOk = true
    private var flutter = ""
    private var flutterAt = 0L
    private var lastPersistAt = 0L
    private val queuedEvents = AtomicInteger(0)
    private var lastCpu = 0L
    private var lastCpuAt = 0L
    @Volatile private var visible = 0
    @Volatile private var cachedSession = "{}"
    @Volatile private var mainAckAt = SystemClock.uptimeMillis()
    private val mainProbePending = AtomicBoolean(false)
    private val crashing = AtomicBoolean(false)
    private val prefs get() = app.getSharedPreferences("automatic_diagnostics_v314", Context.MODE_PRIVATE)
    private val incidentPrefs get() = app.getSharedPreferences("automatic_incidents_v314", Context.MODE_PRIVATE)
    private val crashPrefs get() = app.getSharedPreferences("automatic_crash_v314", Context.MODE_PRIVATE)
    private val uiPrefs get() = app.getSharedPreferences("ui_diagnostic_breadcrumb_v319", Context.MODE_PRIVATE)

    /** Small synchronous checkpoint: survives a death before the event worker runs. */
    fun checkpointUiAction(detail: String) {
        if (!::app.isInitialized) return
        runCatching {
            uiPrefs.edit().putString("last", JSONObject()
                .put("at", System.currentTimeMillis())
                .put("session", session)
                .put("detail", DiagnosticPolicy.safe(detail, 256)).toString()).commit()
        }
    }


    fun initialize(application: Application) {
        app = application
        val delegate = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                if (crashing.compareAndSet(false, true)) {
                    // No worker locks, no telemetry/all-thread enumeration while crashing.
                    val trace = generateSequence(error) { it.cause }.take(4).joinToString("\nCaused by: ") {
                        it.javaClass.name + "\n" + it.stackTrace.take(35).joinToString("\n")
                    }
                    crashPrefs.edit().putString("fatal", JSONObject()
                        .put("at", System.currentTimeMillis()).put("thread", DiagnosticPolicy.safe(thread.name, 100))
                        .put("trace", trace.take(12000)).put("session", cachedSession).toString()).commit()
                }
            } catch (_: Throwable) { /* preserve the system crash handler even on OOM */ }
            finally {
                if (delegate != null) delegate.uncaughtException(thread, error)
                else { android.os.Process.killProcess(android.os.Process.myPid()); kotlin.system.exitProcess(10) }
            }
        }
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) { visible++; event("ciclo", "Activity iniciada") }
            override fun onActivityStopped(activity: Activity) { visible = (visible - 1).coerceAtLeast(0); event("ciclo", "Activity em segundo plano") }
            override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
        worker.execute { runCatching { recoverAndStart() } }
        worker.scheduleWithFixedDelay({ runCatching {
            if (visible > 0 || PhoneCameraBackgroundService.running || MonitoringForegroundService.isRunning) sample()
        } }, 10, 10, TimeUnit.SECONDS)
    }

    private fun json(value: String?) = runCatching { JSONObject(value ?: "{}") }.getOrDefault(JSONObject())
    private fun recoverAndStart() {
        previous = json(prefs.getString("current", null))
        incidents = runCatching { JSONArray(incidentPrefs.getString("incidents", "[]")) }.getOrDefault(JSONArray())
        val fatal = json(crashPrefs.getString("fatal", null))
        val fatalSession = json(fatal.optString("session"))
        if (fatalSession.has("session")) previous = fatalSession
        // Congela o último clique da sessão encerrada antes do próximo
        // MaterialApp emitir eventos de navegação na sessão recém-aberta.
        val lastUi = json(uiPrefs.getString("last", null))
        if (previous.optString("session").isNotEmpty() &&
            lastUi.optString("session") == previous.optString("session")) {
            previous.put("lastUiActionBeforeExit", lastUi)
        }
        val oldStart = previous.optLong("startedAt")
        if (Build.VERSION.SDK_INT >= 30) runCatching {
            val manager = app.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val exit = manager.getHistoricalProcessExitReasons(app.packageName, 0, 12)
                .filter { it.processName == app.packageName && it.timestamp >= oldStart && oldStart > 0 }
                .maxByOrNull { it.timestamp }
            if (exit != null) lastExit = JSONObject().put("at", exit.timestamp).put("reason", exit.reason)
                .put("status", exit.status).put("importance", exit.importance)
                .put("pssKiB", exit.pss).put("rssKiB", exit.rss)
                .put("classification", DiagnosticPolicy.exitProblem(exit.reason) ?: "Sem evidência de falha")
            // ANR trace is text; native crash tombstones may be binary protobuf, so do not decode those.
            if (exit?.reason == 6) runCatching {
                exit.traceInputStream?.use { stream ->
                    val bytes = ByteArray(32768)
                    var length = 0
                    while (length < bytes.size) {
                        val count = stream.read(bytes, length, bytes.size - length)
                        if (count <= 0) break
                        length += count
                    }
                    lastExit.put("anrMethodsPartial", DiagnosticPolicy.anrMethods(String(bytes, 0, length, Charsets.UTF_8)))
                }
            }
        }
        val reason = when {
            fatal.has("at") -> "Falha Java/Kotlin não tratada"
            lastExit.has("reason") && DiagnosticPolicy.exitProblem(lastExit.optInt("reason")) != null -> DiagnosticPolicy.exitProblem(lastExit.optInt("reason"))
            previous.optBoolean("unhandled") -> "Erro Flutter/Dart não tratado no último uso"
            else -> null
        }
        if (reason != null) {
            val id = previous.optString("session").ifEmpty { "fatal-${fatal.optLong("at")}" }
            val alreadySaved = (0 until incidents.length()).any { incidents.optJSONObject(it)?.optString("id") == id }
            if (!alreadySaved && incidentPrefs.getString("acknowledged", "") != id) {
                val item = JSONObject().put("id", id).put("reason", reason)
                    .put("detectedAt", System.currentTimeMillis()).put("lastExit", lastExit)
                    .put("session", previous).put("fatal", fatal)
                if (incidents.length() >= 3) incidents.remove(0)
                incidents.put(item)
            }
        }
        // Save frozen evidence BEFORE replacing the prior session or clearing fatal.
        val persisted = incidentPrefs.edit().putString("incidents", incidents.toString()).commit()
        recoveryNeedsSaving = !persisted
        if (persisted) crashPrefs.edit().remove("fatal").commit()
        startedAt = System.currentTimeMillis()
        session = UUID.randomUUID().toString()
        PhoneStreamDiagnostics.initialize(app)
        sample()
    }

    fun event(source: String, detail: String, isUnhandled: Boolean = false, urgent: Boolean = false) {
        if (queuedEvents.incrementAndGet() > 64) { queuedEvents.decrementAndGet(); return }
        worker.execute { try { runCatching {
            if (isUnhandled) unhandled = true
            events.addLast(JSONObject().put("at", System.currentTimeMillis())
                .put("source", DiagnosticPolicy.safe(source, 100)).put("detail", DiagnosticPolicy.safe(detail, 2400)))
            while (events.size > 120) events.removeFirst()
            if (isUnhandled || urgent || SystemClock.uptimeMillis() - lastPersistAt >= 2000) persist()
        } } finally { queuedEvents.decrementAndGet() } }
    }

    fun heartbeat(value: String) {
        worker.execute { flutter = DiagnosticPolicy.safe(value, 2000); flutterAt = SystemClock.uptimeMillis() }
    }

    fun report(callback: (String) -> Unit) {
        worker.execute {
            val result = runCatching { JSONObject().put("automatic", true).put("sampleIntervalSeconds", 10)
                .put("retainedSamples", 30).put("retainedEvents", 120).put("uiActionsImmediate", true).put("persistenceOk", persistenceOk)
                .put("pendingIncidents", incidents)
                .put("lastExit", lastExit).put("lastUiAction", json(uiPrefs.getString("last", null)))
                .put("previousSession", previous)
                .put("currentSession", json(cachedSession)).toString() }.getOrDefault("{}")
            main.post { callback(result) }
        }
    }

    fun acknowledge(id: String, callback: (Boolean) -> Unit) {
        worker.execute {
            val retained = JSONArray()
            for (i in 0 until incidents.length()) if (incidents.getJSONObject(i).optString("id") != id) retained.put(incidents.getJSONObject(i))
            val ok = runCatching { incidentPrefs.edit().putString("incidents", retained.toString()).putString("acknowledged", id).commit() }.getOrDefault(false)
            if (ok) incidents = retained
            main.post { callback(ok) }
        }
    }

    private fun sample() {
        val now = SystemClock.uptimeMillis()
        val uiAge = (now - mainAckAt).coerceAtLeast(0)
        if (mainProbePending.compareAndSet(false, true)) main.post {
            mainAckAt = SystemClock.uptimeMillis(); mainProbePending.set(false)
        }
        val runtime = Runtime.getRuntime()
        val memory = ActivityManager.MemoryInfo()
        (app.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory)
        val cpu = android.os.Process.getElapsedCpuTime()
        val cpuPercent = if (lastCpuAt > 0 && now > lastCpuAt) (cpu - lastCpu) * 100.0 / (now - lastCpuAt) else -1.0
        lastCpu = cpu; lastCpuAt = now
        val power = app.getSystemService(Context.POWER_SERVICE) as PowerManager
        val battery = app.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val connectivity = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val net = connectivity.getNetworkCapabilities(connectivity.activeNetwork)
        val sample = JSONObject().put("at", System.currentTimeMillis()).put("uptimeMs", now)
            .put("foreground", visible > 0).put("interactive", power.isInteractive)
            .put("powerSave", power.isPowerSaveMode).put("thermalStatus", power.currentThermalStatus)
            .put("javaHeapBytes", runtime.totalMemory() - runtime.freeMemory()).put("javaHeapMaxBytes", runtime.maxMemory())
            .put("nativeHeapBytes", Debug.getNativeHeapAllocatedSize()).put("availableRamBytes", memory.availMem)
            .put("lowMemory", memory.lowMemory).put("totalRamBytes", memory.totalMem)
            .put("freeStorageBytes", app.filesDir.usableSpace)
            .put("uidRxBytes", TrafficStats.getUidRxBytes(app.applicationInfo.uid))
            .put("uidTxBytes", TrafficStats.getUidTxBytes(app.applicationInfo.uid))
            .put("processCpuPercentOneCore", cpuPercent).put("mainHeartbeatAgeMs", uiAge)
            .put("flutterHeartbeatAgeMs", if (flutterAt > 0) now - flutterAt else -1)
            .put("flutter", flutter).put("cameraPermission", app.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
            .put("wifi", net?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true)
            .put("cellular", net?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true)
            .put("internetValidated", net?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true)
            .put("batteryLevel", battery?.getIntExtra("level", -1) ?: -1)
            .put("batteryScale", battery?.getIntExtra("scale", -1) ?: -1)
            .put("batteryTemperatureTenthsC", battery?.getIntExtra("temperature", -1) ?: -1)
            .put("plugged", battery?.getIntExtra("plugged", -1) ?: -1)
            .put("transmitter", PhoneCameraBackgroundService.automaticMetrics())
        // Only inspect the main stack after a missed probe while foreground; never label it ANR.
        if (visible > 0 && uiAge > 20000) sample.put("mainStallStack", Looper.getMainLooper().thread.stackTrace.take(20).joinToString("\n"))
        samples.addLast(sample)
        while (samples.size > 30) samples.removeFirst()
        persist()
    }

    private fun persist() {
        if (session.isEmpty()) return
        if (recoveryNeedsSaving) {
            persistenceOk = incidentPrefs.edit().putString("incidents", incidents.toString()).commit()
            if (!persistenceOk) return // Never overwrite the only previous-session evidence.
            recoveryNeedsSaving = false
            crashPrefs.edit().remove("fatal").commit()
        }
        lastPersistAt = SystemClock.uptimeMillis()
        val info = app.packageManager.getPackageInfo(app.packageName, 0)
        cachedSession = JSONObject().put("session", session).put("startedAt", startedAt)
            .put("updatedAt", System.currentTimeMillis()).put("version", info.versionName)
            .put("build", info.longVersionCode).put("model", Build.MODEL).put("manufacturer", Build.MANUFACTURER)
            .put("android", Build.VERSION.RELEASE).put("sdk", Build.VERSION.SDK_INT)
            .put("abis", JSONArray(Build.SUPPORTED_ABIS.toList())).put("unhandled", unhandled)
            .put("events", JSONArray(events.toList())).put("samples", JSONArray(samples.toList()))
            .put("transmission", DiagnosticPolicy.safe(PhoneCameraBackgroundService.automaticReport(), 24000))
            .put("rtspStage", app.getSharedPreferences("rtsp_diagnostics", Context.MODE_PRIVATE).getString("stage", "none"))
            .toString()
        persistenceOk = prefs.edit().putString("current", cachedSession).commit() // worker only, bounded to 30 samples/120 events
    }
}
