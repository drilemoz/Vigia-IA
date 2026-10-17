package com.minhacamera

import android.content.Context
import android.os.SystemClock
import java.util.concurrent.atomic.AtomicBoolean

/** Testemunha independente da main thread, apenas durante captura ativa. */
internal class PhoneFreezeObserver(
    context: Context, private val stage: String,
    private val pipeline: PhonePipelineTelemetry,
    private val isLive: () -> Boolean
) {
    private val app = context.applicationContext
    private val enabled = AtomicBoolean(true)
    private val thread = Thread({
        var lastReportAt = 0L
        while (enabled.get()) {
            try { Thread.sleep(4500) } catch (_: InterruptedException) { break }
            if (!enabled.get() || !isLive()) continue
            val now = SystemClock.elapsedRealtime()
            if (pipeline.publishAge(now) > 12000L && now - lastReportAt >= 30000L) {
                lastReportAt = now
                runCatching { PhoneStreamDiagnostics.captureFreeze(app, stage, pipeline.snapshot(now)) }
            }
        }
    }, "phone-freeze-observer-$stage").apply { isDaemon = true }
    init { thread.start() }
    fun stop() { enabled.set(false); thread.interrupt() }
}
