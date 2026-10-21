"""Contratos locais do piloto Media3 RTSP, sem Android SDK.

NÃO substitui compilação Gradle, Flutter analyze/test nem reprodução real.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text('utf8')


class Media3Rtsp317Tests(unittest.TestCase):
    def test_version(self):
        self.assertIn('version: 1.0.320+320', source('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.320.md').is_file())

    def test_dependencies_consistent_with_radio(self):
        gradle = source('android/app/build.gradle.kts')
        for module in ('media3-exoplayer', 'media3-exoplayer-rtsp', 'media3-ui', 'media3-session'):
            self.assertIn(f'implementation("androidx.media3:{module}:1.8.0")', gradle)

    def test_bootstrap_restores_native_media3(self):
        bootstrap = source('tool/bootstrap_android.sh')
        self.assertIn('cp "$ROOT/tool/android/Media3RtspPlatformView.kt" "$KOTLIN_DIR/Media3RtspPlatformView.kt"', bootstrap)
        for module in ('media3-exoplayer-rtsp', 'media3-ui'):
            self.assertIn(f'implementation("androidx.media3:{module}:1.8.0")', bootstrap)
        self.assertEqual(
            source('tool/android/MainActivity.kt'),
            source('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt'))
        self.assertEqual(
            source('tool/android/Media3RtspPlatformView.kt'),
            source('android/app/src/main/kotlin/com/vigiaia/app/Media3RtspPlatformView.kt'))

    def test_factory_and_activity_lifecycle(self):
        activity = source('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        player = source('android/app/src/main/kotlin/com/vigiaia/app/Media3RtspPlatformView.kt')
        self.assertIn('registerViewFactory(', activity)
        self.assertIn('"vigiaia/media3_rtsp"', activity)
        for line in ('media3RtspViews?.pauseAll()', 'media3RtspViews?.resumeAll()', 'media3RtspViews?.disposeAll()'):
            self.assertIn(line, activity)
        for symbol in ('override fun dispose()', 'player?.release()', 'playerView.player = null', 'channel.setMethodCallHandler(null)'):
            self.assertIn(symbol, player)

    def test_actual_first_frame_callback(self):
        player = source('android/app/src/main/kotlin/com/vigiaia/app/Media3RtspPlatformView.kt')
        self.assertIn('override fun onRenderedFirstFrame()', player)
        self.assertIn('firstFrame = true', player)
        self.assertIn('"firstFrame" to firstFrame', player)
        self.assertIn('onVideoSizeChanged(videoSize: VideoSize)', player)
        self.assertIn('RtspMediaSource.Factory()', player)
        self.assertIn('.setForceUseRtpTcp(forceTcp)', player)
        self.assertIn('MediaItem.fromUri(rtspUrl)', player)
        self.assertIn('exo.volume = 0f', player)
        self.assertIn('setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, true)', player)

    def test_no_secrets_in_status_or_errors(self):
        player = source('android/app/src/main/kotlin/com/vigiaia/app/Media3RtspPlatformView.kt')
        start = player.index('private fun status():')
        end = player.index('private fun publish()', start)
        status = player[start:end]
        for secret in ('rtspUrl', 'username', 'password', 'uri', 'message'):
            self.assertNotIn(secret, status)
        self.assertIn('fail(error.errorCodeName)', player)
        self.assertNotIn('error.message', player.split('override fun onPlayerError(error: PlaybackException)')[1].split('})')[0].replace('// error.message pode conter URL e credenciais: expor só o código estável.', ''))

    def test_screen_is_independent_of_monitoring(self):
        screen = source('lib/screens/media3_rtsp_test_screen.dart')
        hub = source('lib/screens/multi_camera_screen.dart')
        card = source('lib/screens/multi_camera_screen_components.dart')
        self.assertIn("AndroidView(", screen)
        self.assertIn("viewType: 'vigiaia/media3_rtsp'", screen)
        self.assertIn("'getStatus'", screen)
        self.assertIn("'retry'", screen)
        self.assertIn("value['firstFrame'] == true", screen)
        self.assertIn("widget.forceTcp", screen)
        self.assertIn('Media3RtspTestScreen(', hub)
        self.assertIn("camera.type == CameraEndpointType.rtsp", hub)
        self.assertIn('Testar H.264 com Media3', card)
        self.assertIn('monitoramento, IA, gravação', screen)

    def test_no_accidental_replacement_of_ai_or_mcrp(self):
        vlc = source('lib/sources/rtsp_camera_source.dart')
        self.assertIn('VlcPlayerController', vlc)
        self.assertIn('takeSnapshot(width: 640)', vlc)
        self.assertIn('RtspCameraSource(', source('lib/controllers/monitor_controller.dart'))
        self.assertIn('RtspCameraSource(', source('lib/controllers/secondary_camera_controller.dart'))


if __name__ == '__main__':
    unittest.main()
