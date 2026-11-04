"""Regressões de fonte para os oito diagnósticos do flutter analyze no APK 281.

Estes testes não substituem executar flutter analyze com o SDK Dart.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def src(path):
    return (ROOT / path).read_text('utf-8')


class Build281FlutterAnalyze336Test(unittest.TestCase):
    def test_route_descent_uses_nullable_receiver(self):
        body = src('lib/screens/map_monitoring_screen.dart')
        self.assertIn('route?.descentMeters?.round() ?? 0', body)
        self.assertNotIn('route.descentMeters?.round()', body)
        self.assertIn('route?.ascentMeters == null', body)

    def test_backup_no_redundant_typed_data_import(self):
        body = src('lib/services/api_credentials_backup_service.dart')
        self.assertNotIn("import 'dart:typed_data';", body)
        self.assertIn("import 'package:flutter/services.dart';", body)
        self.assertIn('invokeMethod<Uint8List>', body)

    def test_backup_avoids_unnecessary_non_null_assertion(self):
        body = src('lib/services/api_credentials_backup_service.dart')
        self.assertIn('final restoredModel = backup._geminiModel;', body)
        self.assertIn('if (restoredModel != null) {', body)
        self.assertIn('saveModel(restoredModel)', body)
        self.assertNotIn('saveModel(backup._geminiModel!)', body)

    def test_geoapify_search_invalid_coordinates_have_blocks(self):
        body = src('lib/services/geoapify_map_search_service.dart')
        self.assertRegex(body, r'latitude\.abs\(\) > 90 \|\| longitude\.abs\(\) > 180\) \{\s*continue;')
        self.assertIn('if (title.isEmpty) {', body)

    def test_geoapify_pois_invalid_coordinates_have_blocks(self):
        body = src('lib/services/geoapify_poi_service.dart')
        self.assertRegex(body, r'coords\[0\] is! num \|\| coords\[1\] is! num\) \{\s*continue;')
        self.assertRegex(body, r'latitude\.abs\(\) > 90 \|\| longitude\.abs\(\) > 180\) \{\s*continue;')

    def test_ors_guards_have_blocks(self):
        body = src('lib/services/map_cycling_route_service.dart')
        self.assertRegex(body, r'raw\[0\] is! num \|\| raw\[1\] is! num\) \{\s*continue;')
        self.assertRegex(body, r'end < begin \|\| end >= points\.length\) \{\s*continue;')
        self.assertIn('if (points.length < 2) {', body)
        self.assertIn('return _valhalla', body) if 'return _valhalla' in body else self.assertIn('valhalla', body.lower())

    def test_public_release_is_sequential_and_history_preserved(self):
        self.assertIn('version: 1.0.345+345', src('pubspec.yaml'))
        self.assertIn('static const int build = 345;', src('lib/core/app_metadata.dart'))
        self.assertTrue((ROOT / 'RELEASE-1.0.345.md').exists())
        self.assertTrue((ROOT / 'VALIDATION-1.0.345.md').exists())
        about = src('lib/screens/app_info_screen_components.dart')
        self.assertEqual(about.count("version: '1.0.345',\n          current: true"), 2)
        self.assertIn("version: '1.0.335',\n          current: false", about)


if __name__ == '__main__':
    unittest.main()
