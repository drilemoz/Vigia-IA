package com.vigiaia.app

import android.content.Context
import android.net.Uri
import android.view.View
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.rtsp.RtspMediaSource
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Reprodutor RTSP de teste, isolado do monitor de IA e do LibVLC/MCRP.
 * Não exporta URL, login, senha nem textos brutos de exceção ao Dart/logs.
 * Cada AndroidView é dono exclusivo do seu player e o libera em dispose().
 */
@OptIn(UnstableApi::class)
internal class Media3RtspPlatformViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val views = mutableSetOf<Media3RtspPlatformView>()
    private var foreground = true

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<Any, Any>()
        val rtspUrl = params["url"] as? String ?: ""
        val forceTcp = params["forceTcp"] as? Boolean ?: true
        return Media3RtspPlatformView(context, messenger, viewId, rtspUrl, forceTcp) {
            views.remove(it)
        }.also {
            views.add(it)
            if (!foreground) it.pause()
        }
    }

    fun pauseAll() {
        foreground = false
        views.toList().forEach { it.pause() }
    }

    fun resumeAll() {
        foreground = true
        views.toList().forEach { it.resume() }
    }

    fun disposeAll() {
        views.toList().forEach { it.dispose() }
        views.clear()
    }
}

@OptIn(UnstableApi::class)
internal class Media3RtspPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val rtspUrl: String,
    private val forceTcp: Boolean,
    private val onDisposed: (Media3RtspPlatformView) -> Unit,
) : PlatformView {
    private val playerView = PlayerView(context).apply {
        useController = false
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        setShutterBackgroundColor(android.graphics.Color.BLACK)
    }
    private val channel = MethodChannel(messenger, "vigiaia/media3_rtsp/$viewId")
    private var player: ExoPlayer? = null
    private var disposed = false
    private var firstFrame = false
    private var state = "connecting"
    private var errorCode: String? = null
    private var width = 0
    private var height = 0
    private var shouldPlay = true

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(status())
                "retry" -> {
                    if (disposed) result.error("disposed", "Player encerrado.", null)
                    else {
                        restart()
                        result.success(status())
                    }
                }
                else -> result.notImplemented()
            }
        }
        val uri = Uri.parse(rtspUrl)
        if (!uri.scheme.equals("rtsp", ignoreCase = true) || uri.host.isNullOrBlank()) {
            fail("URL_INVALIDA")
        } else {
            restart()
        }
    }

    override fun getView(): View = playerView

    private fun status(): Map<String, Any?> = mapOf(
        "state" to state,
        "firstFrame" to firstFrame,
        "errorCode" to errorCode,
        "width" to width,
        "height" to height,
        "forceTcp" to forceTcp,
    )

    private fun publish() {
        if (!disposed) channel.invokeMethod("state", status())
    }

    private fun fail(code: String) {
        state = "error"
        errorCode = code
        publish()
    }

    private fun restart() {
        if (disposed) return
        releasePlayer()
        firstFrame = false
        width = 0
        height = 0
        errorCode = null
        state = "connecting"
        publish()
        // Inicialização/controle no thread principal (PlatformView no Android UI thread).
        try {
            val exo = ExoPlayer.Builder(playerView.context).build()
            player = exo
            playerView.player = exo
            // Prévia visual somente: evita criar decodificador de áudio sem uso.
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, true)
                .build()
            exo.volume = 0f // Sem áudio ou foco do sistema.
            exo.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    if (disposed || player !== exo || state == "error") return
                    state = when (playbackState) {
                        Player.STATE_BUFFERING -> "buffering"
                        Player.STATE_READY -> if (firstFrame) "first_frame" else "ready"
                        Player.STATE_ENDED -> "ended"
                        else -> "connecting"
                    }
                    publish()
                }

                override fun onRenderedFirstFrame() {
                    if (disposed || player !== exo) return
                    firstFrame = true
                    state = "first_frame"
                    publish()
                }

                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    if (disposed || player !== exo) return
                    width = videoSize.width
                    height = videoSize.height
                    publish()
                }

                override fun onPlayerError(error: PlaybackException) {
                    if (disposed || player !== exo) return
                    // error.message pode conter URL e credenciais: expor só o código estável.
                    fail(error.errorCodeName)
                }
            })
            val source = RtspMediaSource.Factory()
                .setForceUseRtpTcp(forceTcp)
                .setTimeoutMs(12_000)
                .createMediaSource(MediaItem.fromUri(rtspUrl))
            exo.setMediaSource(source)
            exo.playWhenReady = shouldPlay
            exo.prepare()
        } catch (_: Exception) {
            releasePlayer()
            fail("PLAYER_INIT_FAILED")
        }
    }

    fun pause() {
        shouldPlay = false
        player?.playWhenReady = false
    }

    fun resume() {
        if (disposed) return
        shouldPlay = true
        if (state != "error" && state != "ended") player?.playWhenReady = true
    }

    private fun releasePlayer() {
        playerView.player = null
        player?.release()
        player = null
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        releasePlayer()
        onDisposed(this)
    }
}
