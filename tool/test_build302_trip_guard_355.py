"""Previne regressão do workflow 302 no teste do mapa do planejamento."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREEN = (ROOT / 'lib/screens/trip_planning_screen.dart').read_text(encoding='utf-8')
GUARD = (ROOT / 'tool/test_trip_planning_wizard_285.py').read_text(encoding='utf-8')

class Build302Guard355(unittest.TestCase):
    def test_preview_passes_same_trip_to_map_and_actions(self):
        preview = re.search(r'Widget\s+_preview\(\s*PlannedBikeTrip\s+(\w+)\s*\)', SCREEN)
        self.assertIsNotNone(preview)
        arg = preview.group(1)
        self.assertIn(f'_routeMap({arg})', SCREEN)
        self.assertIn(f'_routeActions({arg})', SCREEN)

    def test_legacy_guard_is_not_tied_to_old_identifier(self):
        self.assertNotIn("self.assertIn('_routeMap(route)',self.screen)", GUARD)
        self.assertIn('trip_name = preview.group(1)', GUARD)
        self.assertIn('self.assertIsNotNone(preview', GUARD)

    def test_preserves_offline_preview(self):
        self.assertIn('RetainedMbTilesTileProvider?', SCREEN)
        self.assertIn('if (!_showOnlineBaseMap && provider != null)', SCREEN)

if __name__ == '__main__':
    unittest.main()
