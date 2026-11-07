"""Contratos de conferência MANUAL persistida para paradas offline na 362."""
from pathlib import Path
import unittest
R = Path(__file__).resolve().parents[1]
def source(path): return (R/path).read_text(encoding='utf-8')

class TripStopChecks362(unittest.TestCase):
    def test_model_guards_stale_stage(self):
        model = source('lib/models/trip_stop_check.dart')
        for term in ('bool matches(', 'day == stage.day', 'routeIndex == selectedRouteIndex',
                     'stopLatitude', 'stopLongitude', 'endDistanceMeters',
                     'accessChecked', 'waterChecked', 'overnightChecked'):
            self.assertIn(term, model)
        for forbidden in ('HttpClient', 'Geolocator', 'http.get', 'BackgroundService'):
            self.assertNotIn(forbidden, model)

    def test_trip_roundtrip_legacy_and_corruption_handling(self):
        model = source('lib/models/planned_bike_trip.dart')
        for term in ("'stopChecks':", "json['stopChecks']", 'TripStopCheck.fromJson',
                     'stopChecks: List<TripStopCheck>.unmodifiable(stopChecks)',
                     'List<TripStopCheck>? stopChecks', 'catch (_)'):
            self.assertIn(term, model)

    def test_ui_has_manual_checklist_and_immediate_storage(self):
        screen = source('lib/screens/trip_planning_screen.dart')
        for term in ('_editStopCheck(', 'Acesso pela via conferido', 'Água conferida',
                     'Pernoite conferido', 'Salvar no aparelho', 'Notas offline',
                     'Conferência antiga: parada alterada, revisar', '_library.upsert(updated)',
                     'identical(_draft, current)'):
            self.assertIn(term, screen)
        self.assertNotIn('http', screen[screen.index('Future<void> _editStopCheck('):screen.index('Widget _dayCard(')])

    def test_readiness_does_not_contradict_manual_checks(self):
        service = source('lib/services/trip_effort_reserve_service.dart')
        screen = source('lib/screens/trip_planning_screen.dart')
        for term in ('overnightManuallyChecked', 'accessManuallyChecked'):
            self.assertIn(term, service)
            self.assertIn(term, screen)

    def test_does_not_evict_existing_trips_or_truncate_checks(self):
        screen = source('lib/screens/trip_planning_screen.dart')
        trip = source('lib/models/planned_bike_trip.dart')
        self.assertIn('PlannedBikeTripService.maximumTrips', screen)
        self.assertIn('updatedChecks.length > 400', screen)
        self.assertIn('stopChecks.take(400)', trip)
        self.assertIn('rawChecks.take(400)', trip)

    def test_regression_dart_cases_present(self):
        test = source('test/trip_stop_check_362_test.dart')
        self.assertGreaterEqual(test.count("test('"), 6)
        self.assertIn('JSON antigo', test)
        self.assertIn('rota', test)

if __name__ == '__main__': unittest.main()
