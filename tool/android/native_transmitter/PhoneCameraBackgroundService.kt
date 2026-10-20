package com.minhacamera

import com.vigiaia.app.MainActivity
import com.vigiaia.app.R
import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.Camera
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.view.OrientationEventListener
import android.view.Surface
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Captura MJPEG independente da Activity. O usuário ativa este serviço com a tela visível,
 * antes de bloquear o aparelho. START_NOT_STICKY evita reabrir a câmera sem autorização
 * em um processo restaurado em segundo plano (restrição Android 14+).
 *
 * Uma câmera por vez. Nenhuma dependência da TextureView nem de instâncias de Activity.
 */
@Suppress("DEPRECATION")
class PhoneCameraBackgroundService : Service() {
    companion object {
        @Volatile private var diagnosticInstance: PhoneCameraBackgroundService? = null
        internal fun automaticReport(): String = diagnosticInstance?.diagnosis() ?: PhoneStreamDiagnostics.report()
        internal fun automaticMetrics(): org.json.JSONObject {
            val service = diagnosticInstance
            return org.json.JSONObject().put("running", running).put("recording", recording)
                .put("phase", startupPhase).put("recAccepted", recorderAccepted).put("recBusyDropped", recorderBusyDropped)
                .put("captured", service?.frameCount ?: 0).put("targetFps", service?.fpsLimit ?: 0)
                .put("recordingTargetFps", service?.recordingFps ?: 0).put("codec", service?.liveCodec ?: "none")
                .put("captureAgeMs", service?.let { (SystemClock.elapsedRealtime() - it.lastCaptureAtMs).coerceAtLeast(0) } ?: -1)
                .put("publishedAgeMs", service?.let { (SystemClock.elapsedRealtime() - it.lastPublishedAtMs).coerceAtLeast(0) } ?: -1)
                .put("heatState", service?.heatState?.toString() ?: "none")
                .put("viewers", service?.server?.activeVideoViewers() ?: 0)
        }
        private const val CHANNEL = "phone-camera-background-v1"
        private const val NOTIFICATION_ID = 1047
        const val ACTION_START = "com.vigiaia.app.TRANSMITTER_START"
        const val ACTION_STOP = "com.vigiaia.app.TRANSMITTER_STOP"
        const val ACTION_RECORD = "com.vigiaia.app.TRANSMITTER_RECORD"
        const val ACTION_SCENE_PHOTOS = "com.vigiaia.app.TRANSMITTER_SCENE_PHOTOS"
        const val EXTRA_ENABLED = "enabled"
        const val SCENE_PHOTOS_PREF = "scene_photos_enabled"
        const val ACTION_CODEC = "com.vigiaia.app.TRANSMITTER_CODEC"
        const val ACTION_QUALITY = "com.vigiaia.app.TRANSMITTER_QUALITY"
        const val ACTION_FPS = "com.vigiaia.app.TRANSMITTER_FPS"
        const val ACTION_ORIENTATION = "com.vigiaia.app.TRANSMITTER_ORIENTATION"
        const val EXTRA_ORIENTATION = "orientation_mode"
        fun changeOrientationLocal(context: Context, mode: String) {
            context.startService(Intent(context, PhoneCameraBackgroundService::class.java).apply {
                action = ACTION_ORIENTATION
                putExtra(EXTRA_ORIENTATION, PhoneOrientationMode.normalize(mode))
            })
        }
        const val EXTRA_CODEC = "codec"
        fun changeSettingsLocal(context: Context, action: String, value: Int) {
            context.startService(Intent(context, PhoneCameraBackgroundService::class.java).apply {
                this.action = action
                putExtra("value", value)
            })
        }
        fun commandScenePhotos(context: Context, enabled: Boolean) {
            context.startService(Intent(context, PhoneCameraBackgroundService::class.java).apply {
                action = ACTION_SCENE_PHOTOS
                putExtra(EXTRA_ENABLED, enabled)
            })
        }
        fun changeCodecLocal(context: Context, desired: String) {
            context.startService(Intent(context, PhoneCameraBackgroundService::class.java).apply {
                action = ACTION_CODEC
                putExtra(EXTRA_CODEC, desired)
            })
        }
        const val EXTRA_FACING = "facing"

        @Volatile var running = false
            private set
        @Volatile var recording = false
            private set
        @Volatile var scenePhotosSaved = 0
            private set
        @Volatile var recorderAccepted = 0
            private set
        @Volatile var recorderBusyDropped = 0
            private set
        @Volatile var streamUrl: String? = null
            private set
        @Volatile var latestJpeg: ByteArray? = null
            private set
        @Volatile internal var latestBattery: PhoneBatteryReading? = null
            private set
        @Volatile var transmissionStartedMs: Long = 0L
            private set
        @Volatile var lastError: String? = null
            private set
        /** A Activity nunca deve retomar a câmera enquanto o serviço inicia ou libera recursos. */
        @Volatile var starting: Boolean = false
            private set
        @Volatile var releasing: Boolean = false
            private set
        @Volatile var firstFramePublished: Boolean = false
            private set
        @Volatile var startupPhase: String = "parado"
            private set

        fun command(context: Context, action: String, facing: Int = Camera.CameraInfo.CAMERA_FACING_BACK) {
            val intent = Intent(context, PhoneCameraBackgroundService::class.java).apply {
                this.action = action
                putExtra(EXTRA_FACING, facing)
            }
            if (action == ACTION_START) ContextCompat.startForegroundService(context, intent)
            else context.startService(intent)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val encodeWorker = Executors.newSingleThreadExecutor { r -> Thread(r, "phone-background-mjpeg") }
    private val recordWorker = Executors.newSingleThreadExecutor { r -> Thread(r, "phone-background-mp4") }
    private val photoWorker = Executors.newSingleThreadExecutor { r -> Thread(r, "phone-background-scene-photo") }
    private val sceneGate = PhoneScenePhotoGate()
    private val sceneSaveBusy = AtomicBoolean(false)
    @Volatile private var scenePhotosEnabled = false
    private val encoding = AtomicBoolean(false)
    private val recordingBusy = AtomicBoolean(false)
    private val torch by lazy { PhoneTorchController(mainHandler, { recording }, { heatState }) }
    private val battery by lazy { PhoneBatteryTelemetry(applicationContext) }
    @Volatile private var zoomAvailable = false
    @Volatile private var zoomPercent = 0
    @Volatile private var zoomRatio100 = 100
    @Volatile private var maxZoomRatio100 = 100
    /** Zoom da câmera do serviço: funciona com a tela apagada, sem depender da Activity. */
    private fun applyServiceZoom(percent: Int): Boolean {
        val current = camera ?: return false
        if (!zoomAvailable || closing || switching || liveCodec != "mjpeg" || percent !in 0..100) return false
        return try {
            val params = current.parameters
            if (!params.isZoomSupported || params.maxZoom <= 0) return false
            val step = ((params.maxZoom.toLong() * percent + 50) / 100).toInt().coerceIn(0,params.maxZoom)
            params.zoom = step
            current.parameters = params
            val confirmed = current.parameters
            zoomPercent = (confirmed.zoom * 100 / params.maxZoom).coerceIn(0,100)
            zoomRatio100 = confirmed.zoomRatios?.getOrNull(confirmed.zoom) ?: 100
            true
        } catch (_: Exception) { false }
    }

    private fun setServiceZoom(percent: Int): Boolean {
        if (!running || closing || switching || liveCodec != "mjpeg" || !zoomAvailable) return false
        if (Looper.myLooper() == Looper.getMainLooper()) return applyServiceZoom(percent)
        val latch = CountDownLatch(1)
        val success = AtomicBoolean(false)
        mainHandler.post {
            try { success.set(running && applyServiceZoom(percent)) }
            finally { latch.countDown() }
        }
        return latch.await(2, TimeUnit.SECONDS) && success.get()
    }

    private var camera: Camera? = null
    private var headlessPreview: PhoneHeadlessPreview? = null
    private var selectedFacing = Camera.CameraInfo.CAMERA_FACING_BACK
    @Volatile private var remoteResolution = ""
    @Volatile private var requestedQuality = 480
    private val publishedFps = PhonePublishedFps()
    private val pipelineProbe = PhonePipelineTelemetry("serviço MJPEG/H264")
    private var freezeObserver: PhoneFreezeObserver? = null
    @Volatile private var fpsLimit = 10
    @Volatile private var switching = false
    @Volatile private var takingPhoto = false
    @Volatile private var recordingStartMs = 0L
    @Volatile private var server: PhoneCameraServer? = null
    private var liveEncoder: PhoneH264LiveEncoder? = null // somente encodeWorker
    @Volatile private var liveCodec = "mjpeg"
    @Volatile private var codecPending = false
    @Volatile private var h264FailedThisSession = false
    private var lastJpegPreviewAt = 0L
    @Volatile private var lastCaptureAtMs = 0L
    @Volatile private var frameCount = 0L
    private var recorder: PhoneMp4Recorder? = null // acessado só pelo recordWorker
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private val streamPacer = PhoneFramePacer()
    private val recordPacer = PhoneFramePacer()
    @Volatile private var recordingGeneration = 0L
    @Volatile private var recordingFps = 10
    @Volatile private var physicalDegrees = 0
    @Volatile private var frameRotationDegrees = 0
    private var activeSensorMount = 90
    private var activeFrontFacing = false
    private var currentOrientationMode = PhoneOrientationMode.AUTO
    private val orientationStabilizer = PhoneOrientationStabilizer()
    private val orientationSensor by lazy { object : OrientationEventListener(this) {
        override fun onOrientationChanged(orientation: Int) {
            orientationStabilizer.observe(orientation, SystemClock.elapsedRealtime())?.let { degrees ->
                physicalDegrees = degrees
                refreshFrameRotation()
            }
        }
    } }
    private fun refreshFrameRotation() {
        if (recording || closing || switching || takingPhoto || !running) return
        val device = PhoneOrientationMode.deviceDegrees(currentOrientationMode, physicalDegrees)
        val computed = PhoneOrientationMode.frameDegrees(activeSensorMount, activeFrontFacing, device)
        if (computed != frameRotationDegrees) {
            val wasPortrait = frameRotationDegrees % 180 != 0
            frameRotationDegrees = computed
            if ((computed % 180 != 0) != wasPortrait) {
                // H.264 só aceita dimensões fixas por encoder; limpa CSD e reinicia no worker.
                try { encodeWorker.execute {
                    liveEncoder?.close(); liveEncoder = null
                    server?.clearAvc()
                } } catch (_: Exception) { }
            }
            PhoneStreamDiagnostics.add("Orientação do fluxo atualizada: $computed graus")
        }
    }
    @Volatile private var lastPublishedAtMs = 0L
    private var watchdogRestarts = 0
    private val frameWatchdog = object : Runnable {
        override fun run() {
            if (!running || closing) return
            val age = SystemClock.elapsedRealtime() - lastPublishedAtMs
            if (age > 4_000) PhoneStreamDiagnostics.add("Sem quadros publicados por ${age}ms; codec=$liveCodec; captura=${SystemClock.elapsedRealtime()-lastCaptureAtMs}ms; ${headlessPreview?.health()}")
            if (age > 12_000 && !switching && !takingPhoto && !recording) {
                PhoneStreamDiagnostics.captureFreeze(applicationContext, "serviço / $liveCodec",
                    pipelineProbe.snapshot(SystemClock.elapsedRealtime()) + "\n" + (headlessPreview?.health() ?: "sem superfície"))
                if (watchdogRestarts >= 3) {
                    lastError = "A câmera parou de enviar quadros após tentativas de recuperação"
                    stopCaptureAndFinish()
                    return
                }
                watchdogRestarts++
                // 1080p/30 exige muitas cópias NV21 e compressões JPEG no Redmi A3.
                // Somente após um travamento efetivo, recuperar em perfil progressivamente leve.
                val newQuality = PhoneBackgroundRecovery.nextQuality(requestedQuality)
                val newFps = PhoneBackgroundRecovery.nextFps(fpsLimit)
                val lastCallbackAge = SystemClock.elapsedRealtime() - lastCaptureAtMs
                PhoneStreamDiagnostics.add("Watchdog: publicação parada ${age}ms, callback ${lastCallbackAge}ms; " +
                    "tentativa=$watchdogRestarts, qualidade $requestedQuality->$newQuality, FPS $fpsLimit->$newFps")
                fpsLimit = newFps
                firstFramePublished = false
                startupPhase = "recuperando quadros"
                // Atualizar valor efetivo, inclusive no protocolo remoto.
                getSharedPreferences("phone_video", MODE_PRIVATE).edit().putInt("remote_fps", newFps).apply()
                server?.let { reconfigure(it, selectedFacing, newQuality) }
            }
            mainHandler.postDelayed(this, 6000)
        }
    }
    @Volatile private var heatState = PhoneHeatState.NORMAL
    @Volatile private var thermalStatus = -1
    private var lastThermalReadAt = 0L
    private var lastIdlePreviewAt = 0L

    /** O sensor termico do SoC nao e o termometro da bateria. Consulta <=1/5s. */
    private fun updateThermalPolicy(now: Long) {
        if (now - lastThermalReadAt < 5_000L) return
        lastThermalReadAt = now
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            thermalStatus = try {
                (getSystemService(Context.POWER_SERVICE) as PowerManager).currentThermalStatus
            } catch (_: Exception) { -1 }
        }
        val thermalHeat = when {
            thermalStatus >= PowerManager.THERMAL_STATUS_SEVERE -> PhoneHeatState.HOT
            thermalStatus >= PowerManager.THERMAL_STATUS_MODERATE -> PhoneHeatState.WARM
            else -> PhoneHeatState.NORMAL
        }
        val batteryHeat = PhoneEcoPolicy.heatState(cachedBattery?.temperatureTenthsC, heatState)
        val next = if (thermalHeat.ordinal > batteryHeat.ordinal) thermalHeat else batteryHeat
        if (heatState != next) {
            heatState = next
            torch.onStateChanged()
            PhoneStreamDiagnostics.add("Termica: estado=$next, statusAndroid=$thermalStatus")
            mainHandler.post { applyCameraFpsRange() }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            thermalStatus >= PowerManager.THERMAL_STATUS_EMERGENCY && !closing) {
            lastError = "Temperatura critica: captura encerrada para proteger o aparelho"
            PhoneStreamDiagnostics.add("Protecao termica critica: interrompendo captura/gravação com finalizacao segura")
            mainHandler.post { if (!closing) stopCaptureAndFinish() }
        }
    }
    private var lastBatteryReadAt = 0L
    private var cachedBattery: PhoneBatteryReading? = null
    @Volatile private var ecoEnabled = false
    @Volatile private var closing = false
    private var foregroundStarted = false
    @Volatile private var pendingCameraStart = false
    private var startGeneration = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        diagnosticInstance = this
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(
                NotificationChannel(CHANNEL, "Vigia IA · Transmissão nativa", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopCaptureAndFinish()
            ACTION_ORIENTATION -> if (running && !closing) {
                currentOrientationMode = PhoneOrientationMode.normalize(intent.getStringExtra(EXTRA_ORIENTATION))
                getSharedPreferences("phone_video", MODE_PRIVATE).edit()
                    .putString(PhoneOrientationMode.PREF_KEY, currentOrientationMode).apply()
                if (orientationSensor.canDetectOrientation()) orientationSensor.enable()
                else orientationSensor.disable()
                refreshFrameRotation()
            }
            ACTION_RECORD -> if (running && !closing) toggleRecording()
            ACTION_SCENE_PHOTOS -> {
                val enabled = intent.getBooleanExtra(EXTRA_ENABLED, false)
                getSharedPreferences("phone_video", MODE_PRIVATE).edit()
                    .putBoolean(SCENE_PHOTOS_PREF, enabled).apply()
                scenePhotosEnabled = enabled
                sceneGate.reset()
                PhoneStreamDiagnostics.add("Fotos por movimento: ${if (enabled) "ligadas" else "desligadas"}")
                if (running) updateNotification()
            }
            ACTION_QUALITY -> if (running && !closing && !recording && !switching && !takingPhoto) {
                val profile = intent.getIntExtra("value", -1)
                if (profile in listOf(360, 480, 720, 768, 1080)) {
                    server?.let { reconfigure(it, selectedFacing, profile) }
                }
            }
            ACTION_FPS -> if (running && !closing) {
                val target = intent.getIntExtra("value", -1)
                if (target in listOf(5, 10, 15, 24, 30)) {
                    fpsLimit = target
                    getSharedPreferences("phone_video", MODE_PRIVATE).edit().putInt("remote_fps", target).apply()
                    try { encodeWorker.execute { liveEncoder?.close(); liveEncoder = null; server?.clearAvc() } } catch (_: Exception) { }
                    applyCameraFpsRange()
                }
            }
            ACTION_CODEC -> if (running && !closing) {
                val desired = intent.getStringExtra(EXTRA_CODEC).orEmpty()
                if (!changeStreamCodec(desired)) PhoneStreamDiagnostics.add("Troca de codec rejeitada durante outra operação")
            }
            ACTION_START -> {
                if (server != null && !running && !closing) {
                    resumeRemoteCapture()
                    return START_NOT_STICKY
                }
                if (running || closing || pendingCameraStart || starting || releasing) return START_NOT_STICKY
                starting = true
                lastError = null
                firstFramePublished = false
                h264FailedThisSession = false
                startupPhase = "permissão de câmera"
                PhoneStreamDiagnostics.add("Tela apagada: serviço recebeu solicitação de início")
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                    lastError = "Permissão de câmera negada"
                    starting = false
                    startupPhase = "permissão negada"
                    stopSelf()
                    return START_NOT_STICKY
                }
                // startForeground deve ocorrer enquanto a Activity solicitante ainda está visível.
                try {
                    lastError = null
                    startCameraForegroundNotification()
                    foregroundStarted = true
                    startupPhase = "preparando superfície EGL"
                    PhoneStreamDiagnostics.add("Tela apagada: foreground iniciado; preparando EGL")
                    ecoEnabled = getSharedPreferences("phone_video", MODE_PRIVATE).getBoolean("eco_enabled", true)
                    scenePhotosEnabled = getSharedPreferences("phone_video", MODE_PRIVATE)
                        .getBoolean(SCENE_PHOTOS_PREF, false)
                    sceneGate.reset()
                    scenePhotosSaved = 0
                    recorderAccepted = 0
                    recorderBusyDropped = 0
                    requestedQuality = getSharedPreferences("phone_video", MODE_PRIVATE).getInt("remote_quality", 480)
                    fpsLimit = getSharedPreferences("phone_video", MODE_PRIVATE).getInt("remote_fps", 10)
                    liveCodec = getSharedPreferences("phone_video", MODE_PRIVATE).getString("stream_codec", "mjpeg")
                        ?.takeIf { it == "h264" } ?: "mjpeg"
                    currentOrientationMode = PhoneOrientationMode.normalize(
                        getSharedPreferences("phone_video", MODE_PRIVATE)
                            .getString(PhoneOrientationMode.PREF_KEY, null))
                    physicalDegrees = PhoneOrientationMode.fromDisplayDegrees(
                        when ((getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.rotation) {
                            Surface.ROTATION_90 -> 90
                            Surface.ROTATION_180 -> 180
                            Surface.ROTATION_270 -> 270
                            else -> 0
                        })
                    PhoneStreamDiagnostics.add("Solicitada captura em segundo plano: $liveCodec")
                    val facing = intent.getIntExtra(EXTRA_FACING, Camera.CameraInfo.CAMERA_FACING_BACK)
                    pendingCameraStart = true
                    val generation = ++startGeneration
                    // Inicializar EGL em outra thread evita travar a interface por até 4 s.
                    Thread({
                        val prepared = try { PhoneHeadlessPreview.create(640, 480) }
                            catch (e: Exception) {
                                mainHandler.post {
                                    if (generation == startGeneration && !closing) {
                                        lastError = "Preparação EGL: ${e.javaClass.simpleName}"
                                        PhoneStreamDiagnostics.add("Tela apagada: $lastError")
                                        stopCaptureAndFinish()
                                    }
                                }
                                return@Thread
                            }
                        mainHandler.post {
                            if (closing || generation != startGeneration) {
                                prepared.close()
                            } else {
                                startupPhase = "abrindo câmera do serviço"
                                PhoneStreamDiagnostics.add("Tela apagada: EGL pronto; abrindo câmera")
                                startPreparedCapture(facing, prepared, generation)
                            }
                        }
                    }, "camera-headless-prepare").apply { isDaemon = true; start() }
                } catch (e: Exception) {
                    lastError = "Inicio de serviço: ${e.javaClass.simpleName}"
                    PhoneStreamDiagnostics.add("Tela apagada: $lastError")
                    stopCaptureAndFinish()
                }
            }
        }
        return START_NOT_STICKY
    }

    /** Permite a Activity liberar a câmera antes de o Service tentar reabri-la.
     *  Somente erros transitórios de Camera/porta provocam uma nova tentativa limitada.
     */
    private fun startPreparedCapture(facing: Int, prepared: PhoneHeadlessPreview, generation: Int,
                                     attempt: Int = 0) {
        if (closing || generation != startGeneration) { prepared.close(); return }
        try {
            startCapture(facing, prepared)
            pendingCameraStart = false
            starting = false
            startupPhase = "aguardando primeiro quadro"
            PhoneStreamDiagnostics.add("Tela apagada: câmera aberta; aguardando quadro publicado")
        } catch (e: Exception) {
            // Se falhou antes de anexar à câmera, a prévia ainda precisa ser liberada.
            prepared.close()
            val cause = e.javaClass.simpleName
            PhoneStreamDiagnostics.add("Tela apagada: falha de inicialização ${attempt + 1}: $cause")
            if (attempt < 2 && generation == startGeneration && !closing) {
                mainHandler.postDelayed({
                    // O primeiro preview foi fechado no rollback de startCapture.
                    // Preparar novo EGL em worker para manter a UI responsiva.
                    Thread({
                        val retryPreview = runCatching { PhoneHeadlessPreview.create(640, 480) }.getOrNull()
                        mainHandler.post {
                            if (retryPreview == null) {
                                lastError = "Falha ao preparar prévia após $cause"
                                stopCaptureAndFinish()
                            } else startPreparedCapture(facing, retryPreview, generation, attempt + 1)
                        }
                    }, "camera-headless-retry").apply { isDaemon = true; start() }
                }, if (attempt == 0) 450L else 1000L)
            } else {
                lastError = "Câmera em segundo plano indisponível ($cause)"
                stopCaptureAndFinish()
            }
        }
    }

    private fun pending(action: String, requestCode: Int): PendingIntent = PendingIntent.getService(
        this, requestCode, Intent(this, PhoneCameraBackgroundService::class.java).apply {
            this.action = action
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Vigia IA · Transmissão nativa")
            .setContentText(when {
                recording -> "Gravando e transmitindo"
                running -> "Transmitindo por Wi-Fi local"
                else -> "Câmera pausada · controle remoto disponível"
            })
            .setContentIntent(open)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .apply { if (running) addAction(0, (if (recording) "Parar REC" else "Gravar"), pending(ACTION_RECORD, 2)) }
            .addAction(0, "Parar transmissão", pending(ACTION_STOP, 3))
            .build()
    }

    private fun startCameraForegroundNotification() {
        if (Build.VERSION.SDK_INT >= 29)
            startForeground(NOTIFICATION_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
        else startForeground(NOTIFICATION_ID, notification())
    }

    private fun updateNotification() {
        if (foregroundStarted) (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, notification())
    }

    private fun startCapture(facing: Int, prepared: PhoneHeadlessPreview? = null) {
        val ip = NetUtil.wifiIpv4(this) ?: throw IllegalStateException("Wi-Fi indisponível")
        val remoteLibrary = PhoneRemoteLibrary(applicationContext)
        val session = PhoneCameraServer(ip, PhoneCameraAccess.token(this),
            changeRecording = { desired ->
                if (!running || closing || switching || (desired && latestJpeg == null)) false
                else { if (recording != desired) mainHandler.post {
                    if (!closing && running && recording != desired) toggleRecording()
                }; true }
            }, recordingStatus = { recording },
            changeTorch = { torch.setMode(it) },
            torchSupported = { torch.supported },
            torchEnabled = { torch.enabled },
            torchMode = { torch.mode },
            changeCodec = { desired -> changeStreamCodec(desired) },
            codecStatus = { liveCodec },
            transmissionSeconds = { if (running && transmissionStartedMs > 0L)
                (SystemClock.elapsedRealtime() - transmissionStartedMs).coerceAtLeast(0) / 1000 else 0L },
            requestKeyframe = { encodeWorker.execute { liveEncoder?.requestKeyframe() } },
            diagnostics = { diagnosis() },
            deviceModel = { Build.MODEL },
            appVersion = { packageManager.getPackageInfo(packageName, 0).versionName ?: "" },
            resolutionStatus = { remoteResolution },
            recordingSeconds = { if (recording) ((SystemClock.elapsedRealtime() - recordingStartMs) / 1000).coerceAtLeast(0) else 0 },
            changeEco = { desired ->
                if (!running || closing) false else {
                    ecoEnabled = desired
                    mainHandler.post { applyCameraFpsRange() }
                    getSharedPreferences("phone_video", MODE_PRIVATE).edit().putBoolean("eco_enabled", desired).apply()
                    true
                }
            }, ecoStatus = { ecoEnabled },
            changeQuality = { quality ->
                if (!running || closing || switching || recording || takingPhoto || quality !in listOf(360, 480, 720, 768, 1080)) false
                else { mainHandler.post { server?.let { active -> reconfigure(active, selectedFacing, quality) } }; true }
            }, qualityStatus = { requestedQuality },
            changeFps = { desired ->
                if (!running || closing || desired !in listOf(5, 10, 15, 24, 30)) false else {
                    fpsLimit = desired
                    try { encodeWorker.execute { liveEncoder?.close(); liveEncoder = null; server?.clearAvc() } } catch (_: Exception) { }
                    mainHandler.post { applyCameraFpsRange() }
                    getSharedPreferences("phone_video", MODE_PRIVATE).edit().putInt("remote_fps", desired).apply()
                    true
                }
            }, fpsStatus = { fpsLimit },
            measuredFpsStatus = { if (running) publishedFps.measured(SystemClock.elapsedRealtime()) else 0 },
            changeZoom = { percent -> setServiceZoom(percent) },
            zoomStatus = { if (running && liveCodec == "mjpeg" && zoomAvailable && !switching) zoomPercent else null },
            zoomRatioStatus = { if (running && liveCodec == "mjpeg" && zoomAvailable && !switching) zoomRatio100 else null },
            zoomMaxRatioStatus = { if (running && liveCodec == "mjpeg" && zoomAvailable && !switching) maxZoomRatio100 else null },
            changeFacing = { desired ->
                if (!running || closing || switching || recording || takingPhoto ||
                    desired !in listOf(Camera.CameraInfo.CAMERA_FACING_BACK, Camera.CameraInfo.CAMERA_FACING_FRONT) ||
                    !hasFacing(desired)) false
                else { mainHandler.post { server?.let { active -> reconfigure(active, desired, requestedQuality) } }; true }
            }, facingStatus = { selectedFacing },
            takePhoto = {
                if (!running || closing || switching || recording || takingPhoto || camera == null) false
                else { takingPhoto = true; mainHandler.post { captureFullPhoto() }; true }
            }, mediaIndex = { remoteLibrary.json() }, mediaOpen = { remoteLibrary.open(it) },
            transmissionActive = { running && !closing },
            thermalStatus = { thermalStatus },
            changeTransmission = { wanted ->
                if (closing || releasing || switching || takingPhoto || recording ||
                    pendingCameraStart || starting || server == null) false
                else if (wanted == running) true
                else {
                    mainHandler.post {
                        if (!closing && !releasing && !recording && server != null) {
                            if (wanted) resumeRemoteCapture() else pauseRemoteCapture()
                        }
                    }
                    true
                }
            })
        try {
            server = session
            openPreview(session, facing, requestedQuality, prepared)
            session.start()
            streamUrl = session.url
            lastError = null
            running = true
            if (orientationSensor.canDetectOrientation()) orientationSensor.enable()
            transmissionStartedMs = SystemClock.elapsedRealtime()
            pipelineProbe.reset(transmissionStartedMs)
            freezeObserver?.stop()
            freezeObserver = PhoneFreezeObserver(applicationContext, "tela-apagada", pipelineProbe) {
                running && !closing && !switching && !takingPhoto
            }
            PhoneStreamDiagnostics.add("Transmissão iniciada: perfil=$requestedQuality, fps=$fpsLimit, codec=$liveCodec")
            lastPublishedAtMs = SystemClock.elapsedRealtime()
            mainHandler.postDelayed(frameWatchdog, 6000)
            acquireLocks()
            updateNotification()
        } catch (e: Exception) {
            session.stop()
            server = null
            releasePreview()
            if (prepared != null && headlessPreview !== prepared) {
                // Mesmo na falha antes de associar, a superfície pré-criada precisa ser fechada.
                runCatching { prepared.close() }
            }
            throw e
        }
    }

    private fun hasFacing(facing: Int) = (0 until Camera.getNumberOfCameras()).any { id ->
        val info = Camera.CameraInfo()
        Camera.getCameraInfo(id, info)
        info.facing == facing
    }

    /** Pausa apenas a captura. HTTP/MCRP e token continuam ativos enquanto o
     *  serviço autorizado estiver vivo. Não interrompe uma gravação em andamento. */
    private fun pauseRemoteCapture() {
        if (!running || closing || recording || switching || takingPhoto || server == null) return
        running = false
        firstFramePublished = false
        transmissionStartedMs = 0L
        latestJpeg = null
        remoteResolution = ""
        startupPhase = "aguardando controle remoto"
        orientationSensor.disable()
        mainHandler.removeCallbacks(frameWatchdog)
        releasePreview()
        server?.clearFrame()
        server?.clearAvc()
        try { if (wifiLock?.isHeld == true) wifiLock?.release() } catch (_: Exception) { }
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) { }
        wifiLock = null
        wakeLock = null
        PhoneStreamDiagnostics.add("Captura pausada remotamente; controle disponível sem câmera")
        updateNotification()
    }

    /** Reabre câmera sem reiniciar servidor/porta/token; o EGL é preparado fora da UI. */
    private fun resumeRemoteCapture() {
        val session = server ?: return
        if (running || starting || closing || releasing || recording || pendingCameraStart) return
        starting = true
        pendingCameraStart = true
        startupPhase = "retomando a câmera"
        val generation = ++startGeneration
        Thread({
            val prepared = try { PhoneHeadlessPreview.create(640, 480) }
                catch (e: Exception) {
                    mainHandler.post {
                        if (generation == startGeneration) {
                            starting = false
                            pendingCameraStart = false
                            lastError = "Retomada EGL: ${e.javaClass.simpleName}"
                            startupPhase = "retomada falhou"
                            updateNotification()
                        }
                    }
                    return@Thread
                }
            mainHandler.post {
                if (closing || generation != startGeneration || server !== session) {
                    prepared.close()
                    return@post
                }
                try {
                    openPreview(session, selectedFacing, requestedQuality, prepared)
                    running = true
                    firstFramePublished = false
                    lastError = null
                    startupPhase = "aguardando primeiro quadro"
                    transmissionStartedMs = SystemClock.elapsedRealtime()
                    pipelineProbe.reset(transmissionStartedMs)
                    lastPublishedAtMs = transmissionStartedMs
                    watchdogRestarts = 0
                    if (orientationSensor.canDetectOrientation()) orientationSensor.enable()
                    acquireLocks()
                    mainHandler.postDelayed(frameWatchdog, 6000)
                    PhoneStreamDiagnostics.add("Captura retomada por comando remoto")
                } catch (e: Exception) {
                    lastError = "Retomada da câmera: ${e.javaClass.simpleName}"
                    startupPhase = "retomada falhou"
                    PhoneStreamDiagnostics.add("Falha na retomada remota: ${e.javaClass.simpleName}")
                    releasePreview()
                    session.clearFrame()
                    session.clearAvc()
                } finally {
                    starting = false
                    pendingCameraStart = false
                    updateNotification()
                }
            }
        }, "camera-remote-resume").apply { isDaemon = true; start() }
    }

    private fun releasePreview() {
        torch.detach()
        val old = camera
        camera = null
        zoomAvailable = false
        zoomPercent = 0
        zoomRatio100 = 100
        try { old?.setPreviewCallbackWithBuffer(null) } catch (_: Exception) { }
        try { old?.stopPreview() } catch (_: Exception) { }
        try { old?.release() } catch (_: Exception) { }
        // Enfileira a liberação no mesmo worker de codificação, preservando a ordem.
        try { encodeWorker.execute { liveEncoder?.close(); liveEncoder = null; server?.clearAvc() } } catch (_: Exception) { }
        headlessPreview?.close()
        headlessPreview = null
    }

    /** Reconfigura no thread principal, sem recriar HTTP/token e sem executar durante MP4. */
    private fun reconfigure(session: PhoneCameraServer, facing: Int, quality: Int) {
        if (server !== session || closing || switching || recording || takingPhoto) return
        switching = true
        PhoneStreamDiagnostics.add("Reconfiguração câmera: lente=$facing, qualidade=$quality")
        val oldFacing = selectedFacing
        val oldQuality = requestedQuality
        releasePreview()
        latestJpeg = null
        session.clearFrame()
        try {
            openPreview(session, facing, quality)
            lastError = null
        } catch (e: Exception) {
            lastError = "Câmera indisponível: ${e.javaClass.simpleName}"
            PhoneStreamDiagnostics.add(lastError ?: "Falha na câmera")
            try { releasePreview(); openPreview(session, oldFacing, oldQuality) }
            catch (_: Exception) { stopCaptureAndFinish() }
        } finally { switching = false }
    }

    private fun openPreview(session: PhoneCameraServer, facing: Int, quality: Int,
                            prepared: PhoneHeadlessPreview? = null) {
        val deviceId = (0 until Camera.getNumberOfCameras()).firstOrNull { id ->
            val info = Camera.CameraInfo()
            Camera.getCameraInfo(id, info)
            info.facing == facing
        } ?: throw IllegalStateException("Câmera indisponível")
        val cameraOpeningAt = SystemClock.elapsedRealtime()
        PhoneStreamDiagnostics.add("Tela apagada: Camera.open solicitada")
        val opened = Camera.open(deviceId)
        PhoneStreamDiagnostics.add("Tela apagada: Camera.open concluiu em ${SystemClock.elapsedRealtime() - cameraOpeningAt}ms")
        camera = opened
        val params = opened.parameters
        val sizes = params.supportedPreviewSizes.orEmpty().filter { it.width > 0 && it.height > 0 && it.width * it.height <= 1920 * 1080 }
        val target = quality // altura da imagem em paisagem é o lado menor (360/480/720).
        val size = sizes.minByOrNull { kotlin.math.abs(minOf(it.width, it.height) - target) * 10 +
            kotlin.math.abs(maxOf(it.width, it.height) - target * (if (target == 768) 4 else 16) / (if (target == 768) 3 else 9)) } ?: throw IllegalStateException("Resolução indisponível")
        remoteResolution = "${size.width}x${size.height}"
        params.setPreviewSize(size.width, size.height)
        params.previewFormat = ImageFormat.NV21
        val photo = params.supportedPictureSizes.orEmpty().maxByOrNull { it.width.toLong() * it.height }
        if (photo != null) params.setPictureSize(photo.width, photo.height)
        params.jpegQuality = 95
        // Somente JPEG nativo: a prévia/stream NV21 já tem sua rotação própria.
        val pictureInfo = Camera.CameraInfo()
        Camera.getCameraInfo(deviceId, pictureInfo)
        params.setRotation(PhoneOrientationMode.frameDegrees(pictureInfo.orientation,
            pictureInfo.facing == Camera.CameraInfo.CAMERA_FACING_FRONT,
            PhoneOrientationMode.deviceDegrees(currentOrientationMode, physicalDegrees)))
        val initialFps = effectiveCameraFps()
        val range = params.supportedPreviewFpsRange.orEmpty().minByOrNull {
            kotlin.math.abs(it[0] - initialFps * 1000) + kotlin.math.abs(it[1] - initialFps * 1000)
        }
        if (range != null) try { params.setPreviewFpsRange(range[0], range[1]) } catch (_: Exception) { }
        if (params.supportedFocusModes?.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO) == true)
            params.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO
        opened.parameters = params
        torch.attach(opened, facing == Camera.CameraInfo.CAMERA_FACING_BACK)
        zoomAvailable = params.isZoomSupported && params.maxZoom > 0
        maxZoomRatio100 = if (zoomAvailable) params.zoomRatios?.lastOrNull()?.coerceAtLeast(100) ?: 100 else 100
        zoomPercent = 0
        zoomRatio100 = 100
        val info = Camera.CameraInfo()
        Camera.getCameraInfo(deviceId, info)
        activeSensorMount = info.orientation
        activeFrontFacing = info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT
        frameRotationDegrees = PhoneOrientationMode.frameDegrees(info.orientation, activeFrontFacing,
            PhoneOrientationMode.deviceDegrees(currentOrientationMode, physicalDegrees))
        val preview = prepared ?: PhoneHeadlessPreview.create(size.width, size.height)
        preview.surfaceTexture.setDefaultBufferSize(size.width, size.height)
        headlessPreview = preview
        opened.setPreviewTexture(preview.surfaceTexture)
        val byteCount = size.width * size.height * 3 / 2
        streamPacer.reset()
        recordPacer.reset()
        sceneGate.reset()
        lastPublishedAtMs = SystemClock.elapsedRealtime()
        opened.setPreviewCallbackWithBuffer { bytes, source ->
            if (bytes != null) {
                lastCaptureAtMs = SystemClock.elapsedRealtime()
                frameCount++
                pipelineProbe.callback(lastCaptureAtMs)
                updateThermalPolicy(lastCaptureAtMs)
            }
            // Saídas independentes: um encoder/rede ocupado nunca bloqueia o REC.
            if (bytes != null && server === session && !closing && !switching && bytes.size >= byteCount) {
                val capturedNs = System.nanoTime()
                val rotationForFrame = frameRotationDegrees
                val generationForFrame = recordingGeneration
                val recordDue = recording && recordPacer.accept(capturedNs,
                    PhoneEcoPolicy.streamIntervalMs(recordingFps, false, heatState))
                val takeRecord = recordDue && recordingBusy.compareAndSet(false, true)
                if (recordDue && !takeRecord) recorderBusyDropped++
                // Sem receptor, apenas amostras de status; o REC mantém sua cadência.
                val idle = session.activeVideoViewers() == 0
                val streamInterval = if (idle) 2_500L else
                    PhoneEcoPolicy.streamIntervalMs(fpsLimit, ecoEnabled && !recording, heatState)
                val takeStream = streamPacer.accept(capturedNs, streamInterval) &&
                    encoding.compareAndSet(false, true)
                if (takeRecord || takeStream) {
                    // Uma cópia compartilhada e imutável; devolver o buffer Camera imediatamente.
                    val snapshot = bytes.copyOf(byteCount)
                    if (takeRecord) appendRecording(snapshot, size.width, size.height, capturedNs,
                        rotationForFrame, generationForFrame)
                    if (takeStream) {
                        pipelineProbe.accepted(SystemClock.elapsedRealtime())
                        try {
                            encodeWorker.execute {
                                try {
                                    pipelineProbe.worker(SystemClock.elapsedRealtime())
                                    if (server === session && !closing && !switching) {
                                        val rotated = Nv21Frames.rotated(snapshot, size.width, size.height, rotationForFrame)
                                        val width = if (rotationForFrame % 180 == 0) size.width else size.height
                                        val height = if (rotationForFrame % 180 == 0) size.height else size.width
                                        publish(session, rotated, width, height, capturedNs)
                                    }
                                } catch (e: Exception) {
                                    pipelineProbe.failed(e.javaClass.simpleName)
                                    PhoneStreamDiagnostics.add("Falha no worker de vídeo: ${e.javaClass.simpleName}")
                                } finally { encoding.set(false) }
                            }
                        } catch (_: Exception) { encoding.set(false) }
                    }
                }
            }
            try { if (bytes != null) source.addCallbackBuffer(bytes) } catch (_: Exception) { }
        }
        repeat(3) { opened.addCallbackBuffer(ByteArray(byteCount)) }
        val previewStartAt = SystemClock.elapsedRealtime()
        PhoneStreamDiagnostics.add("Tela apagada: Camera.startPreview solicitado")
        opened.startPreview()
        PhoneStreamDiagnostics.add("Tela apagada: Camera.startPreview concluiu em ${SystemClock.elapsedRealtime() - previewStartAt}ms")
        selectedFacing = facing
        requestedQuality = quality
        getSharedPreferences("phone_video", MODE_PRIVATE).edit().putInt("remote_quality", quality).apply()
        // Preserve degradacao termica durante reinicio do preview.
    }

    private fun effectiveCameraFps(): Int {
        val target = if (recording) maxOf(fpsLimit, recordingFps) else fpsLimit
        return when {
            heatState == PhoneHeatState.HOT -> minOf(target, 2)
            heatState == PhoneHeatState.WARM || (ecoEnabled && !recording) -> minOf(target, 5)
            else -> target
        }
    }

    private fun applyCameraFpsRange() {
        val opened = camera ?: return
        if (switching || takingPhoto || closing) return
        try {
            val params = opened.parameters
            val effectiveFps = effectiveCameraFps()
            val range = params.supportedPreviewFpsRange.orEmpty().minByOrNull {
                kotlin.math.abs(it[0] - effectiveFps * 1000) + kotlin.math.abs(it[1] - effectiveFps * 1000)
            } ?: return
            params.setPreviewFpsRange(range[0], range[1])
            opened.parameters = params
        } catch (_: Exception) { /* Mantém limite de quadros por software. */ }
    }

    /** JPEG nativo no maior tamanho anunciado pelo hardware; reinicia preview após takePicture. */
    private fun captureFullPhoto() {
        val opened = camera
        if (!running || closing || opened == null || recording) { takingPhoto = false; return }
        try {
            mainHandler.postDelayed({
                if (takingPhoto && !closing) {
                    takingPhoto = false
                    server?.let { reconfigure(it, selectedFacing, requestedQuality) }
                }
            }, 8000)
            opened.takePicture(null, null, Camera.PictureCallback { jpeg, source ->
                if (jpeg != null && jpeg.isNotEmpty()) {
                    try { encodeWorker.execute {
                        val saved = PhoneRemotePhoto.save(applicationContext, jpeg)
                        if (!saved) lastError = "Não foi possível salvar a foto"
                    } } catch (_: Exception) { }
                }
                try {
                    if (!closing && camera === source) {
                        // Alguns aparelhos descartam buffers de callback ao tirar fotos.
                        val sz = source.parameters.previewSize
                        source.startPreview()
                        // Alguns dispositivos devolvem zero buffers após uma captura estática.
                        repeat(3) { source.addCallbackBuffer(ByteArray(sz.width * sz.height * 3 / 2)) }
                    }
                } catch (_: Exception) { lastError = "Prévia não retomada após foto" }
                takingPhoto = false
            })
        } catch (_: Exception) { takingPhoto = false; lastError = "Falha ao capturar foto" }
    }

    private fun acquireLocks() {
        try {
            wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "VigiaIA:BackgroundCapture")
                .apply { acquire() }
        } catch (_: Exception) { }
        try {
            @Suppress("DEPRECATION")
            wifiLock = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "VigiaIA:BackgroundWifi")
                .apply { acquire() }
        } catch (_: Exception) { }
    }

    private fun publish(session: PhoneCameraServer, frame: ByteArray, width: Int, height: Int, capturedNs: Long) {
        if (server !== session || closing || !running) return
        val now = SystemClock.elapsedRealtime()
        val reading = if (cachedBattery == null || now - lastBatteryReadAt >= 2000L) {
            battery.read().also { cachedBattery = it; lastBatteryReadAt = now }
        } else requireNotNull(cachedBattery)
        latestBattery = reading
        // Relata a geometria PUBLICADA (não a dimensão bruta do sensor).
        remoteResolution = "${width}x${height}"
        session.updateBattery(reading)
        updateThermalPolicy(now)
        // Sem receptor, manter somente amostras periódicas durante a gravação.
        // Mesmo sem visualizador, publicar periodicamente mantém o endpoint acessível.
        if (!PhoneRecNetworkPolicy.shouldPublish(recording, session.activeVideoViewers(),
                now, lastPublishedAtMs)) return
        if (liveCodec == "h264") {
            try {
                if (liveEncoder == null) {
                    liveEncoder = PhoneH264LiveEncoder(width, height, fpsLimit,
                        (if (ecoEnabled) 750_000 else if (requestedQuality >= 720) 2_000_000 else 1_250_000)) { bytes, keyframe ->
                        session.publishAvc(bytes, keyframe)
                        publishedFps.mark(SystemClock.elapsedRealtime())
                        lastPublishedAtMs = SystemClock.elapsedRealtime()
                        pipelineProbe.published(lastPublishedAtMs)
                        markFirstPublishedFrame()
                        watchdogRestarts = 0
                    }
                    PhoneStreamDiagnostics.add("Encoder AVC inicializado: ${width}x$height, $fpsLimit fps")
                }
                liveEncoder?.append(frame, capturedNs)
                // Apenas uma miniatura JPEG ocasional para a prévia local, sem publicar MJPEG.
                if (now - lastJpegPreviewAt >= 1500L) {
                    lastJpegPreviewAt = now
                    val preview = ByteArrayOutputStream()
                    if (YuvImage(frame, ImageFormat.NV21, width, height, null)
                            .compressToJpeg(Rect(0, 0, width, height), 60, preview)) {
                        val encoded = preview.toByteArray()
                        latestJpeg = encoded
                        maybeSaveScenePhoto(frame, width, height, encoded)
                    }
                }
            } catch (e: Exception) {
                h264FailedThisSession = true
                pipelineProbe.failed(e.javaClass.simpleName)
                PhoneStreamDiagnostics.add("Encoder H264: ${e.javaClass.simpleName}; " +
                    "retornando para MJPEG, H.264 bloqueado nesta sessão")
                lastError = "H.264 indisponível: ${e.javaClass.simpleName}"
                liveEncoder?.close(); liveEncoder = null
                liveCodec = "mjpeg"
                getSharedPreferences("phone_video", MODE_PRIVATE).edit().putString("stream_codec", "mjpeg").apply()
                session.clearAvc()
            }
        }
        if (liveCodec != "mjpeg") { return }
        val jpeg = ByteArrayOutputStream()
        if (!YuvImage(frame, ImageFormat.NV21, width, height, null)
                .compressToJpeg(Rect(0, 0, width, height), PhoneEcoPolicy.jpegQuality(ecoEnabled, heatState), jpeg)) return
        if (server !== session || closing) return
        val encoded = jpeg.toByteArray()
        latestJpeg = encoded
        lastPublishedAtMs = SystemClock.elapsedRealtime()
        session.publish(encoded, reading)
        pipelineProbe.published(lastPublishedAtMs)
        publishedFps.mark(SystemClock.elapsedRealtime())
        markFirstPublishedFrame()
        watchdogRestarts = 0 // Dados da bateria nos headers, nunca gravados nos pixels.
        maybeSaveScenePhoto(frame, width, height, encoded)
    }

    private fun markFirstPublishedFrame() {
        if (!firstFramePublished) {
            firstFramePublished = true
            startupPhase = "transmitindo quadros"
            PhoneStreamDiagnostics.add("Tela apagada: primeiro quadro publicado")
        }
    }

    /** Somente mudança de cena, sem afirmar que houve detecção de veículo.
     *  Reusa JPEG já produzido para o MCRP, sem outra câmera/codificador.
     *  O quota/cooldown também valem sem visualizador no Note 11.
     */
    private fun maybeSaveScenePhoto(frame: ByteArray, width: Int, height: Int, jpeg: ByteArray) {
        if (!scenePhotosEnabled || recording || closing || !running || jpeg.isEmpty()) return
        if (heatState == PhoneHeatState.HOT || sceneSaveBusy.get()) return
        if (!sceneGate.observe(frame, width, height, SystemClock.elapsedRealtime())) return
        if (!sceneSaveBusy.compareAndSet(false, true)) return
        try {
            photoWorker.execute {
                try {
                    if (!scenePhotosEnabled || !running || closing) return@execute
                    if (PhoneRemotePhoto.save(applicationContext, jpeg)) {
                        scenePhotosSaved++
                        PhoneStreamDiagnostics.add("Foto por movimento salva no A3")
                    } else {
                        lastError = "Falha ao salvar foto por movimento"
                    }
                } catch (e: Exception) {
                    lastError = "Foto automática: ${e.javaClass.simpleName}"
                } finally { sceneSaveBusy.set(false) }
            }
        } catch (_: Exception) { sceneSaveBusy.set(false) }
    }

    /** Um quadro em voo no gravador, independente do worker de rede.
     * A câmera envia NV21 original; orientação fixa fica no contêiner MP4. */
    private fun appendRecording(frame: ByteArray, width: Int, height: Int, capturedNs: Long,
                                rotation: Int, generation: Long) {
        try {
            recordWorker.execute {
                try {
                    if (recording && generation == recordingGeneration && !closing) {
                        if (recorder == null) {
                            val prefs = getSharedPreferences("phone_video", MODE_PRIVATE)
                            recorder = PhoneMp4Recorder(applicationContext, width, height,
                                recordingFps,
                                prefs.getInt("record_bitrate", 1_500_000).coerceIn(500_000, 8_000_000),
                                rotation)
                        }
                        val accepted = recorder?.append(frame, capturedNs) == true
                        if (generation == recordingGeneration) {
                            if (accepted) recorderAccepted++ else recorderBusyDropped++
                        }
                    }
                } catch (e: Exception) {
                    try { recorder?.cancel() } catch (_: Exception) { }
                    recorder = null
                    if (generation == recordingGeneration) {
                        recording = false
                        recordingStartMs = 0L
                        torch.onStateChanged()
                        lastError = "Não foi possível gravar: ${e.message?.take(140) ?: e.javaClass.simpleName}"
                        mainHandler.post { applyCameraFpsRange(); updateNotification() }
                    }
                } finally { recordingBusy.set(false) }
            }
        } catch (_: Exception) { recordingBusy.set(false) }
    }

    private fun toggleRecording() {
        PhoneStreamDiagnostics.add(if (recording) "Gravação encerrada" else "Gravação solicitada")
        recording = !recording
        recordingGeneration++
        recordPacer.reset()
        streamPacer.reset()
        if (recording) recordingFps = fpsLimit.coerceIn(5, 30)
        if (recording) { recorderAccepted = 0; recorderBusyDropped = 0 }
        torch.onStateChanged()
        // Em REC, não limitar a 5 FPS somente por modo Eco; manter proteção térmica.
        mainHandler.post { applyCameraFpsRange() }
        recordingStartMs = if (recording) SystemClock.elapsedRealtime() else 0L
        if (!recording) {
            recordWorker.execute { finishRecording() }
            refreshFrameRotation()
        }
        updateNotification()
    }

    private fun finishRecording() {
        val previous = recorder ?: return
        recorder = null
        try { previous.finish() } catch (_: Exception) {
            lastError = "Não foi possível gravar"
            try { previous.cancel() } catch (_: Exception) { }
        }
    }

    private fun stopCaptureAndFinish() {
        if (closing) return
        freezeObserver?.stop()
        freezeObserver = null
        closing = true
        releasing = true
        starting = false
        startupPhase = "liberando câmera"
        PhoneStreamDiagnostics.add("Tela apagada: liberando serviço/câmera")
        startGeneration++
        pendingCameraStart = false
        orientationSensor.disable()
        running = false
        recording = false
        recordingStartMs = 0L
        torch.detach()
        mainHandler.removeCallbacks(frameWatchdog)
        transmissionStartedMs = 0L
        PhoneStreamDiagnostics.add("Transmissão encerrada")
        streamUrl = null
        latestJpeg = null
        latestBattery = null
        val oldServer = server
        server = null
        oldServer?.stop()
        releasePreview()
        encodeWorker.shutdown()
        photoWorker.shutdown()
        // Enquanto a finalização do MP4 estiver pendente, conservar as proteções de suspensão.
        recordWorker.execute {
            try { finishRecording() } finally {
                mainHandler.post {
                    try { if (wifiLock?.isHeld == true) wifiLock?.release() } catch (_: Exception) { }
                    try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) { }
                    wifiLock = null
                    wakeLock = null
                    if (foregroundStarted) stopForeground(STOP_FOREGROUND_REMOVE)
                    foregroundStarted = false
                    releasing = false
                    startupPhase = "parado"
                    PhoneStreamDiagnostics.add("Tela apagada: serviço liberado")
                    stopSelf()
                }
            }
        }
        recordWorker.shutdown()
    }

    private fun changeStreamCodec(desired: String): Boolean {
        if (desired !in listOf("mjpeg", "h264") || closing || switching || !running || recording || takingPhoto) return false
        if (desired == "h264" && h264FailedThisSession) {
            PhoneStreamDiagnostics.add("H.264 rejeitado: encoder já falhou nesta sessão; use MJPEG")
            return false
        }
        if (desired == liveCodec) return true
        // Não anunciar o codec novo antes do primeiro quadro codificado quando não há encoder compatível.
        if (codecPending) return false
        codecPending = true
        try {
            encodeWorker.execute {
                try {
                    liveEncoder?.close(); liveEncoder = null
                    liveCodec = desired
                    server?.clearFrame()
                    server?.clearAvc()
                    PhoneStreamDiagnostics.add("Codec selecionado: $desired")
                    getSharedPreferences("phone_video", MODE_PRIVATE).edit().putString("stream_codec", desired).apply()
                } catch (e: Exception) {
                    PhoneStreamDiagnostics.add("Falha ao alterar codec: ${e.javaClass.simpleName}")
                } finally { codecPending = false }
            }
        } catch (_: Exception) { codecPending = false; return false }
        return true
    }

    private fun diagnosis(): String = PhoneStreamDiagnostics.report(
        "modo=${if (running) "ativo" else "parado"}, codec=$liveCodec, gravando=$recording, " +
            "eco=$ecoEnabled, fotosMovimento=$scenePhotosEnabled, fotosSalvas=$scenePhotosSaved, " +
            "quadrosREC=$recorderAccepted, descartadosREC=$recorderBusyDropped, lanterna=${torch.mode}/${torch.enabled}, capturados=$frameCount, ultimoCallbackMs=${SystemClock.elapsedRealtime()-lastCaptureAtMs}, " +
            "ultimoCodificadoMs=${SystemClock.elapsedRealtime()-lastPublishedAtMs}, tentativas=$watchdogRestarts, " +
            "fase=$startupPhase, termicaAndroid=$thermalStatus, estadoTermico=$heatState, " +
            "visualizadores=${server?.activeVideoViewers() ?: 0}, " +
            "iniciando=$starting, liberando=$releasing, primeiroQuadro=$firstFramePublished, " +
            (headlessPreview?.health() ?: "surface=inativa")
    )

    override fun onDestroy() {
        diagnosticInstance = null
        if (!closing) stopCaptureAndFinish()
        starting = false
        super.onDestroy()
    }
}
