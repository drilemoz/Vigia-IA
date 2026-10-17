package com.minhacamera

/** Recuperação conservadora somente após bloqueio real de quadros no serviço de tela apagada.
 * Nunca aumenta resolução ou FPS na recuperação. Valores suportados pelo menu do transmissor.
 */
internal object PhoneBackgroundRecovery {
    fun nextQuality(current: Int): Int = when {
        current > 720 -> 720
        current > 480 -> 480
        current > 360 -> 360
        else -> 360
    }
    fun nextFps(current: Int): Int = when {
        current > 15 -> 15
        current > 10 -> 10
        else -> 5
    }
}
