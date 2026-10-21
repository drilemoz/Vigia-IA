"""Regressions for background transmitter MP4 timing and opt-in local scene photos."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
def src(name): return (ROOT / name).read_text('utf8')

class TransmitterRecorder307(unittest.TestCase):
    def test_mp4_frame_before_network_encoding_and_uses_capture_clock(self):
        service = src('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt')
        self.assertIn('val capturedNs = System.nanoTime()', service)
        self.assertLess(service.index('appendRecording(snapshot, size.width, size.height, capturedNs,'),
                        service.index('publish(session, rotated, width, height, capturedNs)'))
        self.assertIn('recorder?.append(frame, capturedNs)', service)
        self.assertNotIn('recorder?.append(snapshot, System.nanoTime())', service)
        self.assertIn('recorderBusyDropped++', service)
        self.assertIn('ecoEnabled && !recording', service)
        self.assertIn('mainHandler.post { applyCameraFpsRange() }', service)

    def test_opt_in_scene_only_while_native_service_running(self):
        service = src('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt')
        main = src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        gate = src('android/app/src/main/kotlin/com/minhacamera/PhoneScenePhotoGate.kt')
        ui = src('lib/screens/native_transmitter_screen.dart')
        self.assertIn('getBoolean(SCENE_PHOTOS_PREF, false)', service)
        self.assertIn('scenePhotosEnabled', main)
        self.assertIn('sceneGate.observe(frame, width, height', service)
        self.assertIn('PhoneRemotePhoto.save(applicationContext, jpeg)', service)
        self.assertIn('sceneSaveBusy.compareAndSet(false, true)', service)
        self.assertIn('recording || closing || !running', service)
        self.assertIn('minimumIntervalMs: Long = 30_000L', gate)
        self.assertIn('maximumPhotosPerHour: Int = 60', gate)
        self.assertIn('Não identifica veículos', ui)
        self.assertIn('SwitchListTile.adaptive(', ui)
        self.assertNotIn('api.platerecognizer', gate)
        library = src('android/app/src/main/kotlin/com/minhacamera/PhoneRemoteLibrary.kt')
        self.assertIn('Pictures/VigiaIA/', library)

    def test_version(self):
        self.assertIn('version: 1.0.319+319', src('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.319.md').exists())

if __name__ == '__main__': unittest.main()
