"""Contratos de 1.0.375. Testes de execucao Dart ficam em test/trip_planner_safety_375_test.dart."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

def content(filename):
    return (ROOT / filename).read_text(encoding='utf-8')

class TripPlannerSafety375(unittest.TestCase):
    def test_monotonic_stages(self):
        code = content('lib/services/bike_trip_planner.dart')
        for token in ('minimumAdvance', 'boundedIdealEnd', '.clamp(minEnd, maxEnd)',
                      'candidate.routeDistanceMeters > maxEnd',
                      'candidateEffort - previousTotalEffort > daySeconds',
                      'totalEffortSeconds - candidateEffort >'):
            self.assertIn(token, code)
    def test_goal_and_cutoff_validation(self):
        code = content('lib/services/trip_distance_goal_safety.dart')
        screen = content('lib/screens/trip_planning_screen.dart')
        for token in ('BikeTripSchedule.forDay(', 'ridingMinutes > maxMinutes',
                      'schedule.arrivalMinute > latestArrivalMinute'):
            self.assertIn(token, code)
        self.assertIn('_distanceGoalError()', screen)
        self.assertIn('_validDistanceGoal && _distanceGoalError() == null', screen)
        self.assertIn('Limite diário de pedal:', screen)
    def test_calendar_does_not_accept_past(self):
        screen = content('lib/screens/trip_planning_screen.dart')
        self.assertIn('final firstDate = DateUtils.dateOnly(now);', screen)
        self.assertIn('if (!scheduled.isAfter(DateTime.now()))', screen)
    def test_search_and_restore(self):
        screen = content('lib/screens/trip_planning_screen.dart')
        self.assertIn('onPressed: () => unawaited(_openCitySearch(origin: origin))', screen)
        self.assertIn('final previousOriginText = _originField.text;', screen)
        self.assertIn('final calculated = shouldCalculate && mounted && await _calculate();', screen)
        self.assertIn('_originField.text = previousOriginText;', screen)
    def test_online_map_setting(self):
        service = content('lib/services/map_view_settings_service.dart')
        screen = content('lib/screens/trip_planning_screen.dart')
        self.assertIn("'tripPreviewOnlineBaseMap': _tripPreviewOnlineBaseMap", service)
        self.assertIn('setTripPreviewOnlineBaseMap(bool value)', service)
        self.assertIn('MapViewSettingsService.instance.tripPreviewOnlineBaseMap', screen)
        self.assertIn('.setTripPreviewOnlineBaseMap(value)', screen)
    def test_new_dart_tests(self):
        dart = content('test/trip_planner_safety_375_test.dart')
        self.assertGreaterEqual(dart.count("test('"), 7)
        self.assertIn("stopKm: 20", dart)
        self.assertIn('distanceKm: 300', dart)

if __name__ == '__main__':
    unittest.main()
