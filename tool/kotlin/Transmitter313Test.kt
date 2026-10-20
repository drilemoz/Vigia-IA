package com.minhacamera

import java.nio.ByteBuffer

fun main() {
    val frame = byteArrayOf(1,2,3,4,5,6,7,8,9,10,11,12)
    for (direct in listOf(false, true)) {
        val buffer = if (direct) ByteBuffer.allocateDirect(12) else ByteBuffer.allocate(12)
        for ((planar, expected) in listOf(
            false to byteArrayOf(1,2,3,4,5,6,7,8,10,9,12,11),
            true to byteArrayOf(1,2,3,4,5,6,7,8,10,12,9,11))) {
            check(PhoneYuv420.write(frame, 4, 2, planar, buffer) == 12)
            buffer.flip()
            val result = ByteArray(12); buffer.get(result)
            check(result.contentEquals(expected))
        }
    }
    check(runCatching { PhoneYuv420.write(frame, 3, 2, true, ByteBuffer.allocate(12)) }.isFailure)
    check(runCatching { PhoneYuv420.write(frame, 4, 2, true, ByteBuffer.allocate(10)) }.isFailure)
    val pacer = PhoneFramePacer()
    val count = (0..99).count { pacer.accept(1_000_000_000L + it * 100_000_000L - (it % 2) * 1_000_000L, 100) }
    check(count == 100) { "10 FPS virou $count quadros por jitter" }
    check(!pacer.accept(10_901_000_000L, 100)) // não duplicar um quadro
    check(pacer.accept(30_000_000_000L, 100)) // pausa: retomar sem fila acumulada
    check(!pacer.accept(30_001_000_000L, 100))
    check(pacer.accept(30_002_000_000L, 200)) // troca de perfil
    // Rede lenta/sem receptor não influencia a seleção de quadros do gravador.
    val recording = PhoneFramePacer(); val network = PhoneFramePacer()
    var recorded = 0; var streamed = 0
    for (i in 0..99) {
        val now = 1_000_000_000L + i * 100_000_000L
        if (recording.accept(now, 100)) recorded++
        if (network.accept(now, 2500)) streamed++
    }
    check(recorded == 100 && streamed == 4)
    check(PhoneRecNetworkPolicy.shouldPublish(true, 1, 100, 99))
    check(!PhoneRecNetworkPolicy.shouldPublish(true, 0, 100, 99))
    check(PhoneRecNetworkPolicy.shouldPublish(true, 0, 2600, 99))
    check(PhoneEcoPolicy.streamIntervalMs(30, false, PhoneHeatState.HOT) == 500L)
    check(PhoneEcoPolicy.streamIntervalMs(30, false, PhoneHeatState.WARM) == 200L)
    check(PhoneEcoPolicy.streamIntervalMs(10, true, PhoneHeatState.NORMAL) == 200L)

    fun bytes(n: Int) = byteArrayOf(n.toByte())
    val queue = PhoneAvcQueue(maxPackets = 3, maxBytes = 5, maxAgeMs = 1000)
    val first = queue.cursor(); val second = queue.cursor()
    queue.add(bytes(1), true, 0); queue.add(bytes(2), false, 1); queue.add(bytes(3), false, 2)
    check(queue.read(first, 2)?.bytes?.first() == 1.toByte())
    check(queue.read(first, 2)?.bytes?.first() == 2.toByte())
    check(queue.read(first, 2)?.bytes?.first() == 3.toByte())
    check(queue.read(first, 2) == null)
    check(queue.read(second, 2)?.bytes?.first() == 1.toByte()) // cursor independente
    val slow = queue.cursor()
    queue.add(bytes(4), false, 3); queue.add(bytes(5), false, 4)
    check(queue.read(slow, 4) == null && slow.waitingForKeyframe)
    queue.add(bytes(6), true, 5); queue.add(bytes(7), false, 6)
    check(queue.read(second, 6)?.bytes?.first() == 6.toByte()) // perdeu quadro: não enviar P-frame
    check(queue.read(second, 6)?.bytes?.first() == 7.toByte())
    check(queue.read(slow, 6)?.bytes?.first() == 6.toByte())
    queue.clear()
    queue.add(bytes(8), false, 7)
    check(queue.read(second, 7) == null && second.waitingForKeyframe)
    queue.add(bytes(9), true, 8)
    check(queue.read(second, 8)?.bytes?.first() == 9.toByte())
    queue.add(bytes(10), false, 9)
    check(queue.read(second, 2000) == null && second.waitingForKeyframe) // atrasado > 1s
    queue.add(bytes(11), true, 2001)
    check(queue.read(second, 2001)?.bytes?.first() == 11.toByte())
    queue.add(ByteArray(6), true, 2002) // pacote maior que orçamento invalida cadeia
    queue.add(bytes(12), false, 2003)
    check(queue.read(second, 2003) == null)
    queue.add(bytes(13), true, 2004)
    check(queue.read(second, 2004)?.bytes?.first() == 13.toByte())
    println("PASS: conversão YUV, cadência, saídas independentes, proteção térmica e recuperação AVC")
}
