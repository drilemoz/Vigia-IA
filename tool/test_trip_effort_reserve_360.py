"""Contratos de regressão para o planejamento de esforço e chegada 1.0.360."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
def read(file): return (ROOT/file).read_text(encoding='utf-8')

class EffortReserve360(unittest.TestCase):
    def test_real_profile_only_and_no_elevation_fabrication(self):
        service=read('lib/services/trip_effort_reserve_service.dart')
        self.assertIn('terrain.hasSamples',service)
        self.assertIn('terrain.ascentMeters',service)
        self.assertIn('minutesPer100Meters',service)
        self.assertIn('TripDayReadinessService',service)
        terrain=read('lib/services/trip_terrain_service.dart')
        self.assertIn('h0 == null || h1 == null',terrain)

    def test_trip_schema_backward_compatibility(self):
        trip=read('lib/models/planned_bike_trip.dart')
        for field in ('climbReserveMinutesPer100m','latestArrivalMinute'):
            self.assertIn(f"'{field}':",trip)
            self.assertIn(f"json['{field}']",trip)
        self.assertIn('climbReserveMinutesPer100m = 0',trip)
        self.assertIn("as num).toInt() : 0",trip)
        self.assertIn('18 * 60',trip)

    def test_screen_shows_actual_hours_and_warnings(self):
        screen=read('lib/screens/trip_planning_screen.dart')
        for term in ('TripEffortReserveService.adjustedDay(',
                     'TripDayReadinessService.notices(',
                     'simulatedDays[i]', 'reservedMinutes',
                     'latestArrivalMinute', 'Chegar até'):
            self.assertIn(term,screen)
        self.assertIn('weatherDays: const <TripWeatherDayForecast>[]',screen)

    def test_weather_uses_reserve_only_when_manual(self):
        service=read('lib/services/trip_weather_forecast_service.dart')
        screen=read('lib/screens/trip_planning_screen.dart')
        self.assertIn('TripEffortReserveService.adjustedDay(',service)
        self.assertIn('climbReserveMinutesPer100m: trip.climbReserveMinutesPer100m',screen)
        self.assertIn('TripWeatherForecastService().fetch(',screen)
        self.assertIn('onPressed: departureDate == null || _fetchingWeather',screen)

    def test_dart_tests_included(self):
        tests=read('test/trip_effort_reserve_360_test.dart')
        self.assertGreaterEqual(tests.count("test('"),4)
        self.assertIn('PlannedBikeTrip.fromJson(old)',tests)

if __name__ == '__main__': unittest.main()
