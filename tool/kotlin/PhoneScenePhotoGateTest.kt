package com.minhacamera

private fun nv21(width: Int, height: Int, luma: Int): ByteArray =
    ByteArray(width * height * 3 / 2).apply {
        for (i in 0 until width * height) this[i] = luma.toByte()
    }

fun main() {
    val width = 32
    val height = 24
    val gate = PhoneScenePhotoGate(minimumIntervalMs = 30_000L, maximumPhotosPerHour = 1)
    val dark = nv21(width, height, 16)
    val bright = nv21(width, height, 180)
    check(!gate.observe(dark, width, height, 0L)) { "Primeira amostra não fotografa" }
    check(!gate.observe(bright, width, height, 2_500L)) { "Apenas uma mudança não fotografa" }
    check(gate.observe(dark, width, height, 5_000L)) { "Duas mudanças disparam foto" }
    check(!gate.observe(bright, width, height, 7_500L)) { "Cooldown impede foto" }
    check(!gate.observe(dark, width, height, 40_000L)) { "Quota por hora impede foto" }
    // Após uma hora, o contador deve reiniciar sem disparo cego.
    check(!gate.observe(bright, width, height, 3_605_000L))
    check(gate.observe(dark, width, height, 3_607_500L))
    gate.reset()
    check(!gate.observe(dark, width, height, 0L))
    println("PhoneScenePhotoGate: gatilho, cooldown, quota e reset aprovados")
}
