"""Regressões estruturais GPS e POIs (não substituem flutter analyze)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class GpsPoi365(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding='utf-8')

    def test_android_location_heartbeat_only_for_passive_map(self):
        service = self.read('lib/services/location_tracking_service.dart')
        self.assertIn('Platform.isAndroid && !highAccuracy', service)
        self.assertIn('AndroidSettings(', service)
        self.assertIn('intervalDuration: const Duration(seconds: 15)', service)
        self.assertIn('distanceFilter: 0,', service)
        self.assertIn('geolocator_android: ^5.0.3', self.read('pubspec.yaml'))
        self.assertIn('MapPerformancePolicy.gpsDistanceFilterMeters', service)
        self.assertIn('MapPerformancePolicy.passiveGpsDistanceFilterMeters', service)

    def test_hud_no_longer_equates_stale_fix_to_broken_gps(self):
        screen = self.read('lib/screens/map_monitoring_screen.dart')
        status = self.read('lib/services/map_gps_hud_policy.dart')
        self.assertNotIn("liveGps == null ? 'Sem sinal atual'", screen)
        self.assertIn('MapGpsHudPolicy.label(', screen)
        self.assertIn("return 'GPS ativo';", status)
        self.assertIn("return 'Leitura GPS antiga';", status)
        self.assertIn("return 'Aguardando posição';", status)
        self.assertTrue((ROOT / 'test/map_gps_hud_policy_365_test.dart').exists())

    def test_overpass_fallback_and_timeouts(self):
        service = self.read('lib/services/route_explorer_service.dart')
        self.assertIn('overpass-api.de/api/interpreter', service)
        self.assertIn('overpass.private.coffee/api/interpreter', service)
        self.assertIn('.timeout(const Duration(seconds: 30));', service)
        self.assertIn('connectionTimeout = const Duration(seconds: 5)', service)
        self.assertIn('_humanReadablePoiError(error)', service)
        self.assertIn('Pacote offline', service)
        self.assertIn('_humanReadablePoiError(error)', service)


    def test_map_center_search_does_not_require_gps(self):
        screen = self.read('lib/screens/map_monitoring_screen.dart')
        self.assertIn("label: const Text('Centro do mapa')", screen)
        self.assertIn('service.searchAround(viewportCenter)', screen)
        self.assertIn('selectedCenter = viewportCenter;', screen)
        self.assertIn('service.searchAround(areaCenter)', screen)
        self.assertIn("label: const Text('Perto do GPS')", screen)

    def test_version_metadata(self):
        self.assertIn('version: 1.0.365+365', self.read('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.365.md').exists())

if __name__ == '__main__':
    unittest.main()
