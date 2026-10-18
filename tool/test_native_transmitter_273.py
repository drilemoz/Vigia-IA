"""Contratos preventivos da integracao Kotlin, sem alegar build Android."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
KOTLIN = ROOT / 'android/app/src/main/kotlin'
MODULE = KOTLIN / 'com/minhacamera'


class NativeTransmitterContracts(unittest.TestCase):
    def test_core_camera_service_and_mcrp_protocol(self):
        service = (MODULE / 'PhoneCameraBackgroundService.kt').read_text()
        server = (MODULE / 'PhoneCameraServer.kt').read_text()
        self.assertIn('START_NOT_STICKY', service)
        self.assertIn('PhoneHeadlessPreview.create', service)
        self.assertIn('startForeground(', service)
        self.assertIn('firstFramePublished', service)
        self.assertIn('PhoneCameraAccess.token(this)', service)
        self.assertIn('ServerSocket()', server)
        self.assertIn('8765', server)
        self.assertIn('/live/$token', server)
        self.assertIn('changeZoom:', server)
        self.assertIn('changeTorch:', server)

    def test_permissions_foreground_and_local_channel(self):
        manifest = (ROOT / 'android/app/src/main/AndroidManifest.xml').read_text()
        bridge = (KOTLIN / 'com/vigiaia/app/MainActivity.kt').read_text()
        self.assertIn('com.minhacamera.PhoneCameraBackgroundService', manifest)
        self.assertIn('android:exported="false"', manifest)
        self.assertIn('android:foregroundServiceType="camera"', manifest)
        self.assertIn('android.permission.FOREGROUND_SERVICE_CAMERA', manifest)
        self.assertIn('checkSelfPermission(Manifest.permission.CAMERA)', bridge)
        self.assertIn('vigiaia/native_transmitter', bridge)
        self.assertIn('nativeTransmitterStatus()', bridge)

    def test_bootstrap_restores_all_sources(self):
        source = ROOT / 'tool/android/native_transmitter'
        current = {p.name: p.read_bytes() for p in MODULE.glob('*.kt')}
        preserved = {p.name: p.read_bytes() for p in source.glob('*.kt')}
        self.assertGreaterEqual(len(current), 20)
        self.assertEqual(current, preserved)
        bootstrap = (ROOT / 'tool/bootstrap_android.sh').read_text()
        self.assertIn('tool/android/native_transmitter/', bootstrap)
        self.assertIn('androidx.core:core-ktx', bootstrap)
        self.assertEqual((ROOT / 'tool/AndroidManifest.xml').read_bytes(),
                         (ROOT / 'android/app/src/main/AndroidManifest.xml').read_bytes())

    def test_native_is_exposed_by_default_and_legacy_is_unrouted(self):
        screen = (ROOT / 'lib/screens/camera_mode_screen.dart').read_text()
        native = (ROOT / 'lib/screens/native_transmitter_screen.dart').read_text()
        self.assertIn('NativeTransmitterScreen()', (ROOT / 'lib/screens/launch_mode_screen.dart').read_text())
        self.assertIn('_server.start()', screen)
        self.assertIn('native.running || native.starting || native.releasing', screen)
        self.assertIn('McrpAddress.parse(status.url!)', native)
        self.assertIn('QrImageView(', native)
        self.assertIn('NativeCameraTransmitterService.stop()', native)
        self.assertNotIn('ObjectDetectionService', native)


if __name__ == '__main__':
    unittest.main()
