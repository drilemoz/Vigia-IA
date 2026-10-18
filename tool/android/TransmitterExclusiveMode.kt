package com.vigiaia.app

import android.content.Context
import android.content.Intent

/** Somente o processo Vigia IA e gerenciado; apps/sistema Android nao sao afetados. */
internal object TransmitterExclusiveMode {
    private const val PREFS = "vigia_transmitter_runtime"
    private const val KEY = "exclusive"
    @Volatile private var active = false

    fun enabled(context: Context): Boolean = active ||
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY, false)

    fun apply(context: Context, enabled: Boolean) {
        // Persistido, para bloquear reinicios automaticos de outros servicos.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY, enabled).apply()
        active = enabled
        if (enabled) {
            context.stopService(Intent(context, MonitoringForegroundService::class.java))
            context.stopService(Intent(context, RadioPlaybackService::class.java))
        }
    }
}
