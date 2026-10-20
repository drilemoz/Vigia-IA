package com.vigiaia.app

import android.app.Application

/** Installed before Activity/Flutter/services, including background process starts. */
class VigiaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppDiagnostics.initialize(this)
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        AppDiagnostics.event("Android", "onTrimMemory=$level")
    }

    @Suppress("DEPRECATION")
    override fun onLowMemory() {
        super.onLowMemory()
        AppDiagnostics.event("Android", "onLowMemory")
    }
}
