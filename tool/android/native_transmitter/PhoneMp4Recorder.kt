package com.minhacamera

import android.content.ContentValues
import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecList
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Grava MP4/H.264 sem áudio. Todos os métodos são invocados sequencialmente no worker de quadros. */
@Suppress("DEPRECATION")
internal class PhoneMp4Recorder(private val context: Context, val width: Int, val height: Int,
    private val fps: Int = 12, private val bitrate: Int = 1_500_000,
    private val orientationDegrees: Int = 0) {
    private val temp = File.createTempFile("phone-camera-", ".mp4", context.cacheDir)
    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var track = -1
    private var muxerStarted = false
    private var frames = 0
    private var firstTimestampNs = -1L
    private var lastTimestampUs = -1L
    private var planar = false
    private var stopped = false

    init {
        require(width > 0 && height > 0 && width % 2 == 0 && height % 2 == 0)
        try {
            require(orientationDegrees in listOf(0, 90, 180, 270))
            var failure: Exception? = null
            // Não cair silenciosamente num encoder de CPU em aparelhos modestos.
            for (candidate in MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos) {
                if (!candidate.isEncoder || !candidate.isHardwareAccelerated ||
                    !candidate.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, true) }) continue
                var encoder: MediaCodec? = null
                try {
                    val caps = candidate.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
                    if (!caps.videoCapabilities.areSizeAndRateSupported(width, height, fps.toDouble())) continue
                    val color = when {
                        caps.colorFormats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar) ->
                            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
                        caps.colorFormats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar) ->
                            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
                        else -> continue
                    }
                    encoder = MediaCodec.createByCodecName(candidate.name)
                    val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
                        setInteger(MediaFormat.KEY_COLOR_FORMAT, color)
                        setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                        setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                        setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
                        setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
                    }
                    encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                    encoder.start()
                    codec = encoder
                    planar = color == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
                    PhoneStreamDiagnostics.add("MP4 hardware: ${candidate.name}, ${width}x$height@$fps, rotação=$orientationDegrees")
                    break
                } catch (e: Exception) {
                    failure = e
                    runCatching { encoder?.release() }
                }
            }
            if (codec == null) throw IllegalStateException("Sem encoder H.264 de hardware para ${width}x$height@$fps; tente 480p/10 FPS", failure)
            muxer = MediaMuxer(temp.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4).apply {
                // Orientação no contêiner evita girar todos os pixels para gravar.
                setOrientationHint(orientationDegrees)
            }
        } catch (e: Exception) {
            release(deleteTemp = true)
            throw e
        }
    }

    /** Timestamp capturado no callback da câmera; retorno indica quadro aceito pelo codec. */
    fun append(nv21: ByteArray, timestampNs: Long): Boolean {
        if (stopped) return false
        val encoder = codec ?: return false
        // Liberar buffers prontos ANTES de solicitar novo input reduz descartes
        // em MediaCodec de baixo desempenho, sem bloquear o worker de transmissão.
        drain(false)
        val index = encoder.dequeueInputBuffer(5_000)
        if (index < 0) return false
        val buffer = encoder.getInputBuffer(index) ?: throw IllegalStateException("Encoder sem buffer")
        val count = PhoneYuv420.write(nv21, width, height, planar, buffer)
        if (firstTimestampNs < 0L) firstTimestampNs = timestampNs
        val presentationUs = maxOf(lastTimestampUs + 1, (timestampNs - firstTimestampNs) / 1000)
        encoder.queueInputBuffer(index, 0, count, presentationUs, 0)
        lastTimestampUs = presentationUs
        frames++
        drain(false)
        return true
    }

    /** Retorna URI de Downloads, ou null se não houve quadros válidos. */
    fun finish(): android.net.Uri? {
        if (stopped) return null
        stopped = true
        try {
            if (frames == 0) return null
            val encoder = codec ?: return null
            val eos = encoder.dequeueInputBuffer(300_000)
            if (eos >= 0) encoder.queueInputBuffer(eos, 0, 0, maxOf(0L, lastTimestampUs + 1), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            drain(true)
            if (!muxerStarted || temp.length() < 1024) return null
            muxer?.stop()
            muxerStarted = false
            muxer?.release()
            muxer = null
            return publishToDownloads(context, temp)
        } finally {
            release(deleteTemp = true)
        }
    }

    fun cancel() { stopped = true; release(deleteTemp = true) }

    private fun drain(waitForEos: Boolean) {
        val encoder = codec ?: return
        val info = MediaCodec.BufferInfo()
        val limitNs = System.nanoTime() + 2_000_000_000L
        while (true) {
            val output = encoder.dequeueOutputBuffer(info, if (waitForEos) 10_000 else 0)
            when {
                output == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!waitForEos || System.nanoTime() > limitNs) return
                output == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (muxerStarted) throw IllegalStateException("Formato H.264 alterado durante gravação")
                    track = (muxer ?: return).addTrack(encoder.outputFormat)
                    muxer?.start()
                    muxerStarted = true
                }
                output >= 0 -> {
                    val data = encoder.getOutputBuffer(output)
                    if (data != null && info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0 && muxerStarted) {
                        data.position(info.offset)
                        data.limit(info.offset + info.size)
                        muxer?.writeSampleData(track, data, info)
                    }
                    val eos = (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                    encoder.releaseOutputBuffer(output, false)
                    if (eos) return
                }
            }
        }
    }

    private fun release(deleteTemp: Boolean) {
        try { codec?.stop() } catch (_: Exception) { }
        try { codec?.release() } catch (_: Exception) { }
        codec = null
        try { if (muxerStarted) muxer?.stop() } catch (_: Exception) { }
        try { muxer?.release() } catch (_: Exception) { }
        muxer = null
        muxerStarted = false
        if (deleteTemp) temp.delete()
    }

    companion object {
        private fun publishToDownloads(context: Context, source: File): android.net.Uri {
            val name = "VigiaIA-${SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())}.mp4"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                    put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/VigiaIA")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val resolver = context.contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Downloads indisponível")
                try {
                    resolver.openOutputStream(uri, "w")?.use { output ->
                        FileInputStream(source).use { it.copyTo(output) }
                    } ?: throw IllegalStateException("Não foi possível salvar em Downloads")
                    resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                    return uri
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    throw e
                }
            }
            // Android 7–9 exige WRITE_EXTERNAL_STORAGE concedido pelo usuário antes de gravar.
            val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "VigiaIA")
            if (!folder.exists() && !folder.mkdirs()) throw IllegalStateException("Downloads indisponível")
            val target = File(folder, name)
            FileInputStream(source).use { input -> FileOutputStream(target).use { input.copyTo(it) } }
            MediaScannerConnection.scanFile(context, arrayOf(target.absolutePath), arrayOf("video/mp4"), null)
            return android.net.Uri.fromFile(target)
        }
    }
}
