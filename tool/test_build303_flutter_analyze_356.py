"""Regressão do flutter analyze no workflow Android APK 303 (2 infos fatais)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREEN = (ROOT / 'lib/screens/trip_planning_screen.dart').read_text(encoding='utf-8')


class Build303FlutterAnalyze356(unittest.TestCase):
    def test_open_preview_map_early_return_has_braces(self):
        pattern = (r'if\s*\(\s*_previewOfflineMapId\s*==\s*package\?\.id\s*&&'
                   r'\s*\(package\s*==\s*null\s*\|\|\s*'
                   r'_previewOfflineTileProvider\s*!=\s*null\)\s*\)'
                   r'\s*\{\s*return;\s*\}')
        self.assertRegex(SCREEN, pattern)

    def test_coverage_counter_if_has_braces(self):
        pattern = (r'if\s*\(package\.contains\(\s*'
                   r'latitude:\s*points\[i\]\.latitude,\s*'
                   r'longitude:\s*points\[i\]\.longitude,\s*'
                   r'\)\)\s*\{\s*matches\+\+;\s*\}')
        self.assertRegex(SCREEN, pattern)

    def test_preview_map_logic_kept(self):
        self.assertIn('RetainedMbTilesTileProvider.fromPath', SCREEN)
        self.assertIn('final points = route.points;', SCREEN)
        self.assertIn('if (matches < count)', SCREEN)


if __name__ == '__main__':
    unittest.main()
