package com.minhacamera

/**
 * Durante REC, favorece a codificação MP4 em aparelhos modestos.
 * Mantém amostra de status sem visualizador. Com receptor, a cadência é decidida
 * pelo pacer de rede e pela proteção térmica, sem impor outro teto de 5 FPS.
 */
internal object PhoneRecNetworkPolicy {
    fun shouldPublish(recording: Boolean, viewers: Int, nowMs: Long, lastPublishedAtMs: Long): Boolean {
        if (!recording || viewers > 0) return true
        return nowMs - lastPublishedAtMs >= 2_500L
    }
}
