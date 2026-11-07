"""Regression APK 311: redundant geolocator_android import (structural check only)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SERVICE = (ROOT / 'lib/services/location_tracking_service.dart').read_text(encoding='utf-8')
PUBSPEC = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')

class GeolocatorImportRegression311(unittest.TestCase):
    def test_no_redundant_android_import(self):
        self.assertIn("import 'package:geolocator/geolocator.dart';", SERVICE)
        self.assertNotIn("import 'package:geolocator_android/geolocator_android.dart';", SERVICE)
        self.assertEqual(len(re.findall(r"(?m)^import 'package:geolocator/", SERVICE)), 1)

    def test_android_platform_settings_and_dependency_kept(self):
        for expected in (
            'Platform.isAndroid && !highAccuracy',
            'AndroidSettings(',
            'intervalDuration: const Duration(seconds: 15)',
            'distanceFilter: 0,',
            'Geolocator.getPositionStream(locationSettings: settings)',
            'MapPerformancePolicy.gpsDistanceFilterMeters',
            'MapPerformancePolicy.passiveGpsDistanceFilterMeters',
        ):
            self.assertIn(expected, SERVICE)
        self.assertIn('geolocator_android: ^5.0.3', PUBSPEC)

    def test_current_release_and_history(self):
        self.assertRegex(PUBSPEC, r'(?m)^version: 1\.0\.366\+366$')
        self.assertTrue((ROOT / 'RELEASE-1.0.366.md').exists())
        self.assertTrue((ROOT / 'RELEASE-1.0.365.md').exists())

if __name__ == '__main__':
    unittest.main()
