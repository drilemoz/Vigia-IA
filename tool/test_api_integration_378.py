from tool.release_version_checks import current_release, version_only
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def src(path): return (ROOT/path).read_text()
class ApiIntegration378(unittest.TestCase):
    def test_corridor_partners_and_limit(self):
        s=src('lib/services/map_destination_search_service.dart')
        for value in ('GeoapifyPoiService.search(','maximumSamples: 4','RouteExplorerPoiCatalog.resolveCategory(tags)','maximumProximityMeters: 3500'):
            self.assertIn(value,s)
    def test_category_details(self):
        s=src('lib/services/geoapify_poi_service.dart')
        for value in ('healthcare.pharmacy','commercial.outdoor_and_sport.bicycle','commercial.convenience','openingHours: detail','phone: detail'):
            self.assertIn(value,s)
    def test_provider_and_profiles(self):
        s=src('lib/services/map_cycling_route_service.dart')
        for value in ('foot-walking','driving-car','motorcycle',"provider: 'Geoapify'","provider: 'OpenRouteService'","provider: 'Valhalla'"):
            self.assertIn(value,s)
        s=src('lib/services/saved_bike_route_service.dart')
        self.assertIn("'provider': route.provider",s)
        self.assertIn("provider: route['provider']",s)
    def test_api_probe_individual(self):
        s=src('lib/services/partner_api_key_service.dart')
        for value in ('/v1/geocode/search','/v2/places','/v1/routing','foot-walking','driving-car','Future.wait'):
            self.assertIn(value,s)
        self.assertNotIn('print(key)',s)
    def test_metadata(self):
        self.assertIn('version: ' + current_release(ROOT),src('pubspec.yaml'))
        self.assertIn(version_only(ROOT),src('lib/services/update_news_catalog.dart'))
if __name__=='__main__': unittest.main()
