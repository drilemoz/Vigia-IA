"""Regressão: GitHub Actions APK 305, curly_braces_in_flow_control_structures em map_destination_search_service.dart:613."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SERVICE = (ROOT / 'lib/services/map_destination_search_service.dart').read_text(encoding='utf-8')


class Build305FlutterAnalyze358(unittest.TestCase):
    def test_coordinate_guard_keeps_validation_and_braced_continue(self):
        pattern = (
            r'if\s*\(lat\s*==\s*null\s*\|\|\s*lon\s*==\s*null\s*\|\|'
            r'\s*!lat\.isFinite\s*\|\|\s*!lon\.isFinite\s*\|\|'
            r'\s*lat\.abs\(\)\s*>\s*90\s*\|\|\s*lon\.abs\(\)\s*>\s*180'
            r'\)\s*\{\s*continue;\s*\}'
        )
        self.assertRegex(SERVICE, pattern)

    def test_route_places_and_valid_destination_logic_remain(self):
        self.assertIn('final camping =', SERVICE)
        self.assertIn('MapDestinationSearchResult(', SERVICE)
        self.assertIn("source: 'online'", SERVICE)

    def test_no_unbraced_multiline_coordinate_guard(self):
        self.assertNotRegex(SERVICE, r'lon\.abs\(\)\s*>\s*180\)\s*continue;')


if __name__ == '__main__':
    unittest.main()
