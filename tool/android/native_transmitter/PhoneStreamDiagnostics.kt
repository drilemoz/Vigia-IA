package com.minhacamera

import android.os.SystemClock
import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.ArrayDeque

/** Eventos operacionais sem IP, URLs ou credenciais. Em memória para evitar gravações constantes. */
internal object PhoneStreamDiagnostics {
    private val events = ArrayDeque<String>()
    private const val MAX_EVENTS = 120
    @Volatile private var app: Context? = null
    @Synchronized fun initialize(context: Context) {
        app = context.applicationContext
        val previous = context.getSharedPreferences("private_stream_diagnostics", Context.MODE_PRIVATE)
            .getString("events", "").orEmpty()
        previous.lineSequence().filter { it.isNotBlank() }.toList().takeLast(60).forEach {
            if (events.size < MAX_EVENTS) events.addLast(it.take(180))
        }
        add("Processo iniciado; diagnóstico recuperado")
    }
    @Synchronized fun add(event: String) {
        val safe = event.replace(Regex("https?://\\S+"), "[endereço omitido]")
            .replace(Regex("[a-f0-9]{32}"), "[token omitido]").take(180)
        val at = SimpleDateFormat("HH:mm:ss", Locale.forLanguageTag("pt-BR")).format(Date())
        if (events.size >= MAX_EVENTS) events.removeFirst()
        events.addLast("$at • $safe")
        // Persistência apenas para eventos relevantes, nunca a cada quadro.
        if (event.contains("falha", true) || event.contains("erro", true) ||
            event.contains("quadros", true) || event.contains("watchdog", true) ||
            event.contains("codec", true) || event.contains("encerrada", true) ||
            event.contains("Tela apagada:", true)) {
            runCatching {
                app?.getSharedPreferences("private_stream_diagnostics", Context.MODE_PRIVATE)?.edit()
                    ?.putString("events", events.joinToString("\n"))?.apply()
            }
        }
    }
    /** Amostragem rara, somente em travamento; stack trace contém apenas nomes de métodos. */
    @Synchronized fun captureFreeze(context: Context, phase: String, telemetry: String) {
        if (!investigationEnabled(context)) return
        val runtime = Runtime.getRuntime()
        val usedMiB = (runtime.totalMemory() - runtime.freeMemory()) / 1048576
        val maxMiB = runtime.maxMemory() / 1048576
        val threadStates = Thread.getAllStackTraces().entries.asSequence()
            .filter { (thread, _) -> thread.name.contains("phone", true) || thread.name == "main" || thread.name.contains("camera", true) }
            .take(12).map { (thread, frames) ->
                "${thread.name.take(45)}:${thread.state} " + frames.take(5)
                    .joinToString(" > ") { "${it.className.substringAfterLast('.')}.${it.methodName}" }
            }.joinToString("\n").take(3500)
        val value = "fase=${phase.take(90)}\n$telemetry\nheap=${usedMiB}/${maxMiB}MiB " +
            "threads=\n$threadStates"
        add("Investigação: quadro parado na etapa ${phase.take(55)}")
        app?.getSharedPreferences("private_stream_diagnostics", Context.MODE_PRIVATE)?.edit()
            ?.putString("freeze_snapshot", value.take(5200))?.apply()
    }
    fun investigationEnabled(context: Context): Boolean = context.getSharedPreferences(
        "private_stream_diagnostics", Context.MODE_PRIVATE).getBoolean("investigation_enabled", true)
    fun setInvestigation(context: Context, enabled: Boolean) {
        context.getSharedPreferences("private_stream_diagnostics", Context.MODE_PRIVATE).edit()
            .putBoolean("investigation_enabled", enabled).apply()
        add("Modo investigação ${if (enabled) "ativado" else "desativado"}")
    }
    @Synchronized fun report(context: String = ""): String = buildString {
        append("Vigia IA • Diagnóstico local\n")
        append("Tempo monotônico: ${SystemClock.elapsedRealtime()} ms\n")
        if (context.isNotBlank()) append(context.take(300)).append('\n')
        events.forEach { append(it).append('\n') }
        val stored = app?.getSharedPreferences("private_stream_diagnostics", Context.MODE_PRIVATE)
            ?.getString("freeze_snapshot", null)
        append("\nInvestigação aprofundada: ").append(if (app?.let { investigationEnabled(it) } != false) "ativada" else "desativada")
        if (!stored.isNullOrBlank()) append("\nÚltima parada detectada:\n").append(stored).append('\n')
        val crash = app?.getSharedPreferences("private_crash_diagnostics", Context.MODE_PRIVATE)
            ?.getString("last", null)
        if (!crash.isNullOrBlank()) append("\nCrash Java/Kotlin anterior:\n").append(crash.take(5500))
    }
}
