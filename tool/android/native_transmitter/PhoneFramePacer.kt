package com.minhacamera

/** Relógio de uma saída, usado apenas pelo callback da câmera. Sem fila de atraso. */
internal class PhoneFramePacer {
    private var nextNs = 0L
    private var previousIntervalNs = 0L

    fun reset() { nextNs = 0L; previousIntervalNs = 0L }

    fun accept(nowNs: Long, intervalMs: Long): Boolean {
        val intervalNs = intervalMs.coerceAtLeast(1L) * 1_000_000L
        if (intervalNs != previousIntervalNs) {
            nextNs = 0L
            previousIntervalNs = intervalNs
        }
        // Jitter de 1–2 ms não deve transformar uma câmera de 10 FPS em 5 FPS.
        if (nextNs != 0L && nowNs + 2_000_000L < nextNs) return false
        nextNs = if (nextNs == 0L || nowNs - nextNs >= intervalNs) nowNs + intervalNs
            else nextNs + intervalNs
        return true
    }
}
