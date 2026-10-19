"""Regression for the eight flutter analyze diagnostics from Android APK 258.

The runner of Build 258 analyzed 1.0.306. These structural assertions
are not a substitute for real flutter analyze, test, and Android build.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

def source(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')

class Build258AnalyzerFix(unittest.TestCase):
    def test_async_context_mounted(self):
        dart = source('lib/screens/events_screen.dart')
        self.assertIn('await _vehicleCapture.setEnabled(enabled)', dart)
        self.assertRegex(dart, r'catch \(_\) \{\s+if \(context\.mounted\) \{\s+ScaffoldMessenger\.of\(context\)')
        self.assertIn('void _refreshAfterPlateChange()', dart)
        self.assertRegex(dart, r'void _refreshAfterPlateChange\(\) \{\s+if \(mounted\) setState\(\(\) \{\}\);\s+\}')

    def test_no_protected_set_state_extension(self):
        dart = source('lib/screens/events_screen_actions.dart')
        self.assertIn('_refreshAfterPlateChange();', dart)
        self.assertNotRegex(dart, r'if \(mounted\) setState\(')

    def test_gallery_all_three_ifs_use_braces(self):
        dart = source('lib/screens/remote_gallery_screen.dart')
        self.assertIn('if (_cancelTransfer) {\n            break;\n          }', dart)
        self.assertIn('if (items.isEmpty) {\n', dart)
        self.assertIn('if (files.isEmpty) {\n', dart)
        self.assertNotRegex(dart, r'if \(_cancelTransfer\) break;')
        self.assertNotRegex(dart, r'if \((?:items|files)\.isEmpty\) return')

    def test_vehicle_guard_both_ifs_use_braces(self):
        dart = source('lib/services/vehicle_capture_service.dart')
        self.assertIn('if (match.hits < 2 || chosen != null) {\n', dart)
        self.assertRegex(dart, r'now\.difference\(match\.lastSaved!\) < repeatSameRegion\) \{\s+continue;')
        self.assertNotIn('if (match.hits < 2 || chosen != null) continue;', dart)

    def test_ocr_redundant_import_removed(self):
        dart = source('lib/services/vehicle_plate_ocr_service.dart')
        self.assertNotIn("import 'dart:typed_data';", dart)
        self.assertIn("import 'package:flutter/foundation.dart';", dart)

    def test_release_and_previous_features_preserved(self):
        self.assertIn('version: 1.0.310+310', source('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.310.md').is_file())
        self.assertIn('PhoneScenePhotoGate', source('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt'))
        self.assertIn('class RemoteGalleryScreen', source('lib/screens/remote_gallery_screen.dart'))
        self.assertIn('class VehiclePlateOcrService', source('lib/services/vehicle_plate_ocr_service.dart'))

if __name__ == '__main__':
    unittest.main()
