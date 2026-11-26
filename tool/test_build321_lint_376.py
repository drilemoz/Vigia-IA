"""Regressão da única advertência fatal dos builds Android 320 e 321."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class LintBuild321Test(unittest.TestCase):
    def test_distance_branch_does_not_force_promoted_value(self):
        code = (ROOT / 'lib/services/bike_trip_planner.dart').read_text(encoding='utf8')
        self.assertIn('final usingDistanceToday = distanceGoalMeters != null', code)
        self.assertIn('math.min(routeDistanceMeters, distanceGoalMeters * day).toDouble()', code)
        self.assertNotIn('distanceGoalMeters! * day', code)

    def test_source_build_376(self):
        self.assertGreaterEqual(int((ROOT / 'pubspec.yaml').read_text().split('version: ', 1)[1].split('+', 1)[1].splitlines()[0]), 376)

if __name__ == '__main__':
    unittest.main()
