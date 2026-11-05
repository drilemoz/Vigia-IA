package com.vigiaia.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Recebe apenas os broadcasts protegidos do Android após boot/atualização. */
class MonitorBootRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED ->
                MonitorRecoveryReceiver.notifyIfEnabled(context)
            else -> return
        }
    }
}
