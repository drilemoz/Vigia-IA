"""Regression checks for optional API integrations and offline fallbacks (335).
These inspect the source contracts only; they are not HTTP or Flutter tests.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def source(path):
    return (ROOT / path).read_text(encoding='utf-8')

class PartnerMaps335(unittest.TestCase):
    def test_geocoding_is_optional_with_osm_fallback(self):
        controller = source('lib/services/map_destination_search_service.dart')
        partner = source('lib/services/geoapify_map_search_service.dart')
        self.assertIn('GeoapifyMapSearchService.search', controller)
        self.assertIn('if (remote.isEmpty)', controller)
        self.assertIn('_fetchNominatim(', controller)
        self.assertIn('/v1/geocode/search', partner)
        self.assertIn('PartnerApiProvider.geoapify', partner)
        self.assertIn('distanceMeters: 0', partner)
        self.assertNotIn('print(key)', partner)

    def test_poi_uses_geoapify_only_as_fallback(self):
        controller = source('lib/services/route_explorer_service.dart')
        partner = source('lib/services/geoapify_poi_service.dart')
        self.assertIn('if (collected.isEmpty)', controller)
        self.assertIn('GeoapifyPoiService.search(', controller)
        self.assertIn('/v2/places', partner)
        self.assertIn('return _prioritizeCategoryDiversity(partner)', controller)

    def test_bicycle_ors_with_valhalla_fallback_and_elevation(self):
        routing = source('lib/services/map_cycling_route_service.dart')
        model = source('lib/models/map_cycling_route.dart')
        self.assertIn('MapTravelMode.bicycle', routing)
        self.assertIn('PartnerApiProvider.openrouteservice', routing)
        self.assertIn('/v2/directions/cycling-regular/geojson', routing)
        self.assertIn('HttpHeaders.authorizationHeader', routing)
        self.assertIn('valhalla1.openstreetmap.de', routing)
        self.assertIn('parseOrsGeoJson(', routing)
        self.assertIn("summary['ascent']", routing)
        self.assertIn('ascentMeters', model)
        self.assertIn('route?.ascentMeters', source('lib/screens/map_monitoring_screen.dart'))

    def test_weather_is_on_demand_with_extended_forecast(self):
        weather = source('lib/services/map_weather_service.dart')
        screen = source('lib/screens/map_monitoring_screen.dart')
        self.assertIn("'forecast_hours': '48'", weather)
        self.assertIn("'uv_index'", weather)
        self.assertIn("'shortwave_radiation'", weather)
        self.assertIn('forecastAlongRoute(', weather)
        self.assertIn('_showWeatherAlongRoute()', screen)
        self.assertIn('sampleAt(index)', weather)

    def test_selected_area_is_not_gps_alert_source(self):
        service = source('lib/services/route_explorer_service.dart')
        block = service.split('Future<void> searchAround(', 1)[1].split('void _markResultsAsCache', 1)[0]
        self.assertIn('_areaResults', block)
        self.assertNotIn('_deliverAlerts(', block)
        self.assertNotIn('_results =', block)
        screen = source('lib/screens/map_monitoring_screen.dart')
        self.assertIn('Perto do GPS', screen)
        self.assertIn('searchAround(areaCenter)', screen)
        self.assertNotIn("const Text(\n                                  lookingAtArea", screen)

    def test_shortcuts_are_bounded_and_optional(self):
        settings = source('lib/services/map_ride_settings_service.dart')
        screen = source('lib/screens/map_monitoring_screen.dart')
        self.assertIn("mapQuickShortcuts = <String>[]", settings)
        self.assertIn('.toSet().take(2).toList', settings)
        self.assertIn('Atalhos rápidos no mapa', screen)
        self.assertIn('!hud.showRadioShortcut', screen)
        self.assertIn('!hud.showBikeShortcut', screen)

    def test_release_current(self):
        self.assertIn('version: 1.0.349+349', source('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.348.md').is_file())
        self.assertTrue((ROOT / 'VALIDATION-1.0.348.md').is_file())

if __name__ == '__main__':
    unittest.main()
