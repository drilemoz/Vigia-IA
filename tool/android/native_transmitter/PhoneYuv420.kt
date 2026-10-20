package com.minhacamera

import java.nio.ByteBuffer

/** Escreve NV12/I420 diretamente no buffer do codec, sem um ByteArray por quadro. */
internal object PhoneYuv420 {
    fun write(nv21: ByteArray, width: Int, height: Int, planar: Boolean, out: ByteBuffer): Int {
        require(width > 0 && height > 0 && width % 2 == 0 && height % 2 == 0)
        val size = width * height
        val count = size * 3 / 2
        require(nv21.size >= count && out.capacity() >= count)
        out.clear()
        out.put(nv21, 0, size)
        if (planar) {
            for (i in size until count step 2) out.put(nv21[i + 1])
            for (i in size until count step 2) out.put(nv21[i])
        } else {
            for (i in size until count step 2) {
                out.put(nv21[i + 1])
                out.put(nv21[i])
            }
        }
        return count
    }
}
