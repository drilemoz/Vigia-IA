"""Contratos estáticos 1.0.361: planejamento offline por esforço e paradas."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def content(path): return (ROOT/path).read_text(encoding='utf-8')

class SmartTripStages361(unittest.TestCase):
    def test_cumulative_effort_uses_only_real_altitude(self):
        src=content('lib/services/trip_stage_effort_profile.dart')
        for term in ('b - a', 'a.isFinite && b.isFinite', 'hasElevations',
                     'climbReserveMinutesPer100m', 'metersAtSeconds',
                     'secondsAtMeters', '_interpolate'):
            self.assertIn(term,src)
        self.assertNotIn('HttpClient',src)
        self.assertNotIn('Geolocator',src)

    def test_stage_planner_rejects_overbudget_and_off_route(self):
        src=content('lib/services/bike_trip_planner.dart')
        for term in ('smartStages', 'daySeconds', 'candidateEffort',
                     'segmentEffort > daySeconds',
                     'effort.totalSeconds - candidateEffort',
                     'candidate.routeProximityMeters > 1500',
                     'TripStageEffortProfile.fromRoute'):
            self.assertIn(term,src)

    def test_persistence_fallback_and_disable(self):
        src=content('lib/models/planned_bike_trip.dart')
        for term in ('this.smartStages = true', "'smartStages': smartStages",
                     "json['smartStages'] is bool", 'bool? smartStages'):
            self.assertIn(term,src)

    def test_screen_switch_and_weather_invalidation(self):
        src=content('lib/screens/trip_planning_screen.dart')
        for term in ('Divisão inteligente dos dias',
                     'smartStages: trip.smartStages',
                     '_draft?.smartStages != trip.smartStages',
                     'smartStages: _smartStages',
                     'Expando<BikeTripPlan>',
                     'weatherDays: const <TripWeatherDayForecast>[]'):
            self.assertIn(term,src)
        self.assertIn('_plan(trip).estimate.dayCount',src)
        self.assertIn('stageStops.take(80)',src)
        self.assertIn('Marcadores',src.replace('marcadores','Marcadores'))

    def test_dart_regressions(self):
        src=content('test/trip_smart_stages_361_test.dart')
        self.assertGreaterEqual(src.count("test('"),7)
        self.assertIn('PlannedBikeTrip.fromJson(oldJson)',src)
        self.assertIn('City',src.replace('Cidade','City'))

if __name__=='__main__': unittest.main()
