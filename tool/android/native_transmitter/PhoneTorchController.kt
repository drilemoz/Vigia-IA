package com.minhacamera

import android.hardware.Camera
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** Lanterna da câmera traseira em uso. Não abre outra instância de Camera.
 * Só o thread principal altera Camera.Parameters; OFF na liberação e em bateria quente.
 */
@Suppress("DEPRECATION")
internal class PhoneTorchController(
    private val main: Handler,
    private val recording: () -> Boolean,
    private val heat: () -> PhoneHeatState
) {
    @Volatile var supported: Boolean = false
        private set
    @Volatile var enabled: Boolean = false
        private set
    @Volatile var mode: String = "off"
        private set
    private var current: Camera? = null
    private var expiresAtMs: Long = 0L
    private val tick = object : Runnable {
        override fun run() {
            if (mode == "off" && !enabled) return
            refresh()
            if (mode == "30" || mode == "120" || enabled && mode == "off") main.postDelayed(this, 1000L)
        }
    }

    /** Chamado no thread principal ao adquirir a câmera. Modos não sobrevivem à troca de lente. */
    fun attach(camera: Camera, isRear: Boolean) {
        detach()
        current = camera
        supported = isRear && runCatching {
            val modes = camera.parameters.supportedFlashModes.orEmpty()
            Camera.Parameters.FLASH_MODE_TORCH in modes && Camera.Parameters.FLASH_MODE_OFF in modes
        }.getOrDefault(false)
    }

    fun detach() {
        main.removeCallbacks(tick)
        val old = current
        if (enabled && old != null) setHardware(old, false)
        current = null
        supported = false
        enabled = false
        mode = "off"
        expiresAtMs = 0L
    }

    /** Identificadores fixos: 'off', '30', '120' ou 'record'. O comando confirma execução. */
    fun setMode(desired: String): Boolean {
        if (desired !in setOf("off", "30", "120", "record")) return false
        if (Looper.myLooper() == Looper.getMainLooper()) return applyMode(desired)
        val completed = CountDownLatch(1)
        val success = AtomicBoolean(false)
        if (!main.post { try { success.set(applyMode(desired)) } finally { completed.countDown() } }) return false
        return completed.await(1500, TimeUnit.MILLISECONDS) && success.get()
    }

    private fun applyMode(desired: String): Boolean {
        if (desired != "off" && (!supported || current == null || heat() == PhoneHeatState.HOT)) return false
        val oldMode = mode
        val oldExpiration = expiresAtMs
        mode = desired
        expiresAtMs = when (desired) {
            "30" -> SystemClock.elapsedRealtime() + 30_000L
            "120" -> SystemClock.elapsedRealtime() + 120_000L
            else -> 0L
        }
        if (!refresh()) {
            mode = oldMode
            expiresAtMs = oldExpiration
            return false
        }
        main.removeCallbacks(tick)
        if (mode == "30" || mode == "120" || enabled && mode == "off") main.postDelayed(tick, 1000L)
        return true
    }

    /** Chamado ao mudar estado REC ou ao detectar aquecimento. */
    fun onStateChanged() {
        if (Looper.myLooper() == Looper.getMainLooper()) refresh()
        else main.post { refresh() }
    }

    private fun refresh(): Boolean {
        if (heat() == PhoneHeatState.HOT ||
            (expiresAtMs > 0L && SystemClock.elapsedRealtime() >= expiresAtMs)) {
            mode = "off"
            expiresAtMs = 0L
        }
        val desired = supported && when (mode) {
            "30", "120" -> true
            "record" -> recording()
            else -> false
        }
        if (desired == enabled) return true
        val device = current ?: return !desired
        val applied = setHardware(device, desired)
        if (applied) enabled = desired
        return applied
    }

    private fun setHardware(camera: Camera, on: Boolean): Boolean {
        return try {
            val params = camera.parameters
            val desired = if (on) Camera.Parameters.FLASH_MODE_TORCH else Camera.Parameters.FLASH_MODE_OFF
            if (desired !in params.supportedFlashModes.orEmpty()) return false
            params.flashMode = desired
            camera.parameters = params
            camera.parameters.flashMode == desired
        } catch (_: Exception) { false }
    }
}
