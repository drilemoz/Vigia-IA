"""Regressão dos dois diagnósticos curly_braces do build 326."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

class Build326LintTest(unittest.TestCase):
    def test_poi_guard_has_block(self):
        source = (ROOT / 'lib/services/bike_trip_planner.dart').read_text()
        self.assertRegex(source, r'if\s*\(result.kind == MapDestinationKind.pointOfInterest &&\s*result.poiCategory != null &&\s*result.poiCategory != RouteExplorerCategory.camping\)\s*\{\s*continue;\s*\}')

    def test_rain_route_guard_has_block(self):
        source = (ROOT / 'lib/services/map_cycling_route_service.dart').read_text()
        self.assertRegex(source, r'if\s*\(ranked.isNotEmpty &&\s*\(safeAlternativeCount == 0 \|\| ranked.length > 1\) &&\s*!\(travelMode == MapTravelMode.bicycle &&\s*preference == BikeSurfacePreference.rain &&\s*ranked.first.unknownSurfaceMeters > 0\)\)\s*\{\s*return ranked;\s*\}')
