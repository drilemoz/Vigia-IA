package com.minhacamera

import java.util.ArrayDeque

/** Histórico limitado compartilhado; cada receptor mantém seu cursor.
 * Chamadas protegidas pelo codecLock do servidor. Pacotes são imutáveis.
 * Nunca retoma em P-frame após descarte, troca de encoder ou atraso excessivo. */
internal class PhoneAvcQueue(
    private val maxPackets: Int = 24,
    private val maxBytes: Int = 4 * 1024 * 1024,
    private val maxAgeMs: Long = 1_000L
) {
    data class Packet(val sequence: Long, val bytes: ByteArray, val keyframe: Boolean, val atMs: Long)
    class Cursor internal constructor(internal var next: Long, internal var epoch: Long) {
        var waitingForKeyframe = true
            internal set
    }
    private val packets = ArrayDeque<Packet>()
    private var bytes = 0
    private var sequence = 0L
    private var epoch = 0L

    init { require(maxPackets > 0 && maxBytes > 0 && maxAgeMs > 0) }

    fun cursor(): Cursor = Cursor(sequence + 1, epoch)

    fun clear() {
        packets.clear()
        bytes = 0
        epoch++
    }

    fun add(data: ByteArray, keyframe: Boolean, nowMs: Long) {
        if (data.isEmpty()) return
        sequence++
        if (data.size > maxBytes) { clear(); return }
        packets.addLast(Packet(sequence, data, keyframe, nowMs))
        bytes += data.size
        while (packets.size > maxPackets || bytes > maxBytes) bytes -= packets.removeFirst().bytes.size
    }

    fun read(cursor: Cursor, nowMs: Long): Packet? {
        if (cursor.epoch != epoch) {
            cursor.epoch = epoch
            cursor.waitingForKeyframe = true
        }
        val first = packets.peekFirst() ?: return null
        if (cursor.next < first.sequence) cursor.waitingForKeyframe = true
        for (packet in packets) {
            if (packet.sequence < cursor.next) continue
            cursor.next = packet.sequence + 1
            if (nowMs - packet.atMs > maxAgeMs) {
                cursor.waitingForKeyframe = true
                continue
            }
            if (cursor.waitingForKeyframe && !packet.keyframe) continue
            cursor.waitingForKeyframe = false
            return packet
        }
        return null
    }
}
