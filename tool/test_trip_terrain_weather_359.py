"""Contratos preventivos do relevo offline e consulta manual do clima."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
def source(name): return (ROOT/name).read_text(encoding='utf-8')

class TripTerrainWeather359(unittest.TestCase):
    def test_saved_elevation_is_optional_and_preserved(self):
        model=source('lib/models/map_cycling_route.dart')
        codec=source('lib/services/saved_bike_route_service.dart')
        parse=source('lib/services/map_cycling_route_service.dart')
        for s in ('elevationsMeters','ascentMeters','descentMeters'):
            self.assertIn(s,model)
            self.assertIn(s,codec)
        self.assertIn('elevations.add(',parse)
        self.assertIn('rawElevations is List && rawElevations.length == points.length',codec)

    def test_days_not_inferred_without_altitudes(self):
        service=source('lib/services/trip_terrain_service.dart')
        self.assertIn('heights.length != route.points.length',service)
        self.assertIn('if (h0 == null || h1 == null)',service)
        self.assertIn('overlap / length',service)
        self.assertIn('coverageFraction',service)

    def test_weather_requires_manual_action_and_selected_date(self):
        screen=source('lib/screens/trip_planning_screen.dart')
        weather=source('lib/services/trip_weather_forecast_service.dart')
        self.assertIn('onPressed: departureDate == null || _fetchingWeather',screen)
        self.assertIn('TripWeatherForecastService().fetch(',screen)
        self.assertIn('showDatePicker(',screen)
        self.assertNotIn('TripWeatherForecastService().fetch(',screen.split('Future<void> _initialize()',1)[1].split('Future<void> _selectStartDate()',1)[0])
        self.assertIn('timezone\': \'GMT\'',weather)
        self.assertIn('maxQueriesPerTap = 8',weather)
        self.assertIn('target.isAfter(now.add(',weather)

    def test_weather_persists_but_does_not_block_old_trips(self):
        p=source('lib/models/planned_bike_trip.dart')
        self.assertIn("'weatherDays': [",p)
        self.assertIn("final rawWeather = json['weatherDays'];",p)
        self.assertIn('forecastDays.add(',p)
        self.assertIn("final parsedDate = json['startDate']",p)

    def test_dart_regressions_present(self):
        src=source('test/trip_terrain_weather_359_test.dart')
        self.assertGreaterEqual(src.count("test('"),4)
        self.assertIn('SavedBikeRouteService.decode(',src)

if __name__=='__main__': unittest.main()
