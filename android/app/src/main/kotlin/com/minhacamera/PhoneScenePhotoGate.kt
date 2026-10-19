package com.minhacamera

import kotlin.math.abs

/** Gatilho barato de mudanças de cena, NÃO classificador de veículos.
 *  Recebe NV21 rotacionado, lê só o plano Y por amostragem e limita fotos.
 *  Não abre câmera, não envia foto e não faz OCR.
 */
internal class PhoneScenePhotoGate(
    private val minimumIntervalMs: Long = 30_000L,
    private val maximumPhotosPerHour: Int = 60,
    private val minimumSampleSpacingMs: Long = 2_000L,
) {
    private var previous: IntArray? = null
    private var lastSampleMs = -1L
    private var lastSavedMs = -1L
    private var hourStartMs = -1L
    private var photosThisHour = 0
    private var changeHits = 0

    @Synchronized fun reset() {
        previous = null
        lastSampleMs = -1L
        lastSavedMs = -1L
        hourStartMs = -1L
        photosThisHour = 0
        changeHits = 0
    }

    /** True apenas para movimento visual recente, sem garantia de ser carro. */
    @Synchronized fun observe(nv21: ByteArray, width: Int, height: Int, nowMs: Long): Boolean {
        if (width <= 0 || height <= 0 || nv21.size < width.toLong() * height) return false
        if (lastSampleMs >= 0L && nowMs >= lastSampleMs && nowMs - lastSampleMs < minimumSampleSpacingMs) return false
        if (lastSampleMs >= 0L && nowMs < lastSampleMs) reset()
        lastSampleMs = nowMs
        if (hourStartMs < 0L || nowMs - hourStartMs >= 3_600_000L) {
            hourStartMs = nowMs
            photosThisHour = 0
        }
        // 16 x 12 = 192 pixels por amostra, custo previsível para o A3.
        val cells = IntArray(192)
        for (row in 0 until 12) {
            val y = (height * (2 * row + 1) / 24).coerceIn(0, height - 1)
            for (col in 0 until 16) {
                val x = (width * (2 * col + 1) / 32).coerceIn(0, width - 1)
                cells[row * 16 + col] = nv21[y * width + x].toInt() and 255
            }
        }
        val old = previous
        previous = cells
        if (old == null) return false
        var total = 0
        var movedCells = 0
        for (i in cells.indices) {
            val delta = abs(cells[i] - old[i])
            total += delta
            if (delta >= 24) movedCells++
        }
        // Descarta ruído pontual; mudança ampla pode incluir câmera móvel.
        val changed = total / cells.size >= 12 && movedCells >= 18
        changeHits = if (changed) (changeHits + 1).coerceAtMost(3) else 0
        // Não acumular detecções durante cooldown ou quota esgotada.
        if (photosThisHour >= maximumPhotosPerHour ||
            (lastSavedMs >= 0L && nowMs - lastSavedMs < minimumIntervalMs)) {
            changeHits = 0
            return false
        }
        if (changeHits < 2) return false
        photosThisHour++
        lastSavedMs = nowMs
        changeHits = 0
        return true
    }
}
