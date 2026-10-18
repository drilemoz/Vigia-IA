package com.minhacamera

/** Lógica pura e testável, sem sensores extras e sem serviços em segundo plano. */
internal enum class PhoneHeatState { NORMAL, WARM, HOT }

internal object PhoneEcoPolicy {
    /** Histerese: não alternar entre estados por décimos de grau perto do limite. */
    fun heatState(tempTenthsC: Int?, previous: PhoneHeatState): PhoneHeatState {
        if (tempTenthsC == null || tempTenthsC !in -200..900) return PhoneHeatState.NORMAL
        return when {
            tempTenthsC >= 450 -> PhoneHeatState.HOT
            previous == PhoneHeatState.HOT && tempTenthsC >= 420 -> PhoneHeatState.HOT
            tempTenthsC >= 420 -> PhoneHeatState.WARM
            previous != PhoneHeatState.NORMAL && tempTenthsC >= 400 -> PhoneHeatState.WARM
            else -> PhoneHeatState.NORMAL
        }
    }

    /** Limites de saída MJPEG, não FPS garantido: CPU, câmera e Wi-Fi podem limitar mais. */
    fun intervalMs(ecoEnabled: Boolean, state: PhoneHeatState): Long = when {
        state == PhoneHeatState.HOT -> 300L
        ecoEnabled -> 200L
        else -> 90L
    }

    /** Intervalo mínimo de transmissão: NORMAL respeita FPS pedido sem teto fixo de 11 FPS.
     *  WARM reduz a carga; HOT e Eco permanecem protegidos. Não garante FPS real.
     */
    fun streamIntervalMs(targetFps: Int, ecoEnabled: Boolean, state: PhoneHeatState): Long =
        maxOf(1000L / targetFps.coerceIn(1, 30), when {
            state == PhoneHeatState.HOT -> 500L
            state == PhoneHeatState.WARM -> 200L
            ecoEnabled -> 200L
            else -> 0L
        })

    fun jpegQuality(ecoEnabled: Boolean, state: PhoneHeatState): Int = when {
        state == PhoneHeatState.HOT -> 40
        state == PhoneHeatState.WARM -> 50
        ecoEnabled -> 50
        else -> 72
    }

    /** Prévia dupla local: evitar JPEG decode e Bitmaps demais em aparelho fraco. */
    fun dualPreviewIntervalMs(ecoEnabled: Boolean, state: PhoneHeatState): Long = when {
        state == PhoneHeatState.HOT -> 1000L
        ecoEnabled -> 500L
        else -> 160L
    }
}
