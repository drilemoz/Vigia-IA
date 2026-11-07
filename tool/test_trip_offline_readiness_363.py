"""Regressões estruturais da auditoria offline 1.0.363 (não substitui Flutter)."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

def read(name):
    return (ROOT / name).read_text(encoding='utf-8')

class OfflineReadiness363(unittest.TestCase):
    def test_local_on_demand_only(self):
        service = read('lib/services/trip_offline_readiness_service.dart')
        for forbidden in ('HttpClient(', 'Geolocator', 'MapConnectivityService', 'getCurrentPosition(', 'http.get('):
            self.assertNotIn(forbidden, service)
        self.assertIn('Future<TripOfflineReadinessReport> inspect(', service)
        self.assertIn('File(package.path)', service)
        self.assertIn('stat.size > 0', service)

    def test_does_not_fake_tile_coverage(self):
        service = read('lib/services/trip_offline_readiness_service.dart')
        self.assertIn('_hasValidBounds(map) && map.contains(', service)
        self.assertIn('samplesWithUnknownCoverage', service)
        self.assertIn('samplesOutsideAvailableBounds', service)
        self.assertIn('daysOutsideMapBounds', service)
        self.assertIn('maximumSamples: 121', service)
        self.assertIn('limites', service)

    def test_uses_actual_stop_checks_and_pois(self):
        service = read('lib/services/trip_offline_readiness_service.dart')
        for needle in ('trip.stopChecks.where', 'selectedRouteIndex: trip.selectedIndex',
                       'check.overnightChecked', 'offlinePoiPackages',
                       'RouteCorridorIndex.locate(', 'maximumProximityMeters: 2500'):
            self.assertIn(needle, service)

    def test_ui_does_not_fire_network_or_gps(self):
        screen = read('lib/screens/trip_planning_screen.dart')
        self.assertIn('Verificar preparação offline', screen)
        self.assertIn('_checkOfflineReadiness(', screen)
        self.assertIn('identical(_lastReadinessTrip, trip)', screen)
        self.assertIn('TripOfflineReadinessService.inspect(', screen)
        segment = screen[screen.index('Future<void> _checkOfflineReadiness('):
                         screen.index('Widget _metric(')]
        self.assertNotIn('searchSubmitted(', segment)
        self.assertNotIn('_routeProvider', segment)
        self.assertNotIn('LocationTrackingService', segment)

    def test_dart_cases(self):
        tests = read('test/trip_offline_readiness_363_test.dart')
        self.assertGreaterEqual(tests.count("test('"), 7)
        for token in ('sem arquivos', 'dois arquivos', 'desatualizada', 'expirado'):
            self.assertIn(token, tests)

if __name__ == '__main__':
    unittest.main()
