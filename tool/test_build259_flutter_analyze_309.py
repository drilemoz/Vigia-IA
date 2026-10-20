"""Regression for 2 Flutter Analyzer infos observed in Android APK 259.

This structural check is supplemental; only real flutter analyze can prove
all Dart lints and compilation checks pass.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(name):
    return (ROOT / name).read_text(encoding='utf-8')


class Build259AnalyzerRegression(unittest.TestCase):
    def test_gallery_download_progress_mounted_if_has_explicit_braces(self):
        code = source('lib/screens/remote_gallery_screen.dart')
        self.assertRegex(code, re.compile(
            r'if \(mounted\) \{\s*setState\(\(\) \{\s*'
            r'_completed\+\+;\s*_received = 0;\s*_expected = 0;\s*'
            r'_lastProgressUiAt = null;\s*\}\);\s*\}', re.M))
        self.assertNotRegex(code, r'if \(mounted\) setState\(\(\) \{\s*_completed\+\+;')

    def test_vehicle_photo_camera_cooldown_if_has_explicit_braces(self):
        code = source('lib/services/vehicle_capture_service.dart')
        self.assertRegex(code, re.compile(
            r'if \(lastCameraPhoto != null &&\s*'
            r'now\.difference\(lastCameraPhoto\) < minimumBetweenPhotos\) \{\s*'
            r'continue;\s*\}', re.M))
        self.assertNotIn('< minimumBetweenPhotos) continue;', code)
        self.assertIn('now.difference(match.lastSaved!) < repeatSameRegion', code)

    def test_new_version_preserves_previous_features(self):
        self.assertIn('version: 1.0.317+317', source('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.317.md').is_file())
        self.assertIn('class RemoteGalleryScreen', source('lib/screens/remote_gallery_screen.dart'))
        self.assertIn('class VehiclePlateOcrService', source('lib/services/vehicle_plate_ocr_service.dart'))
        self.assertIn('PhoneScenePhotoGate', source('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt'))


if __name__ == '__main__':
    unittest.main()
