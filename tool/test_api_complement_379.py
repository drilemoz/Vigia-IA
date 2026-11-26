import unittest
from pathlib import Path
from tool.release_version_checks import current_release, version_only
ROOT=Path(__file__).resolve().parents[1]
def src(p): return (ROOT/p).read_text()
class ApiComplement379(unittest.TestCase):
    def test_reverse_fallback(self):
        s=src('lib/services/map_destination_search_service.dart').split('Future<MapDestinationSearchResult> reverseLookup',1)[1].split('Future<List<MapDestinationSearchResult>> _fetchNominatim',1)[0]
        self.assertLess(s.index('if (onlineAllowed)'),s.index('GeoapifyMapSearchService.reverse'))
        self.assertLess(s.index('GeoapifyMapSearchService.reverse'),s.index('_respectNominatimRateLimit'))
        self.assertIn("source: onlineAllowed ? 'coordinate' : 'offline'",s)
    def test_reverse_cache_and_probe(self):
        s=src('lib/services/geoapify_map_search_service.dart')
        for t in ('/v1/geocode/reverse','_reverseCache.length >= 64','latitude: point.latitude, longitude: point.longitude','request.followRedirects = false'):
            self.assertIn(t,s)
        self.assertIn('/v1/geocode/reverse',src('lib/services/partner_api_key_service.dart'))
    def test_complement_manual_only(self):
        s=src('lib/services/route_explorer_service.dart')
        for t in ('complement: requestPermission || saveAsOffline','complement: true','if (complement && collected.isNotEmpty','!DataUsageService.instance.dataSaverEnabled','enabled: missing',"_lastSource == 'cache' ? 'cache' : null"):
            self.assertIn(t,s)
    def test_poi_cache_and_subtypes(self):
        s=src('lib/services/geoapify_poi_service.dart')
        for t in ('amenity.toilet','camping.caravan_site','tourism.sights.bridge','_cache.length >= 32','potabilidade não verificada','Banheiro mapeado'):
            self.assertIn(t,s)
    def test_version(self):
        self.assertEqual(current_release(ROOT),'1.0.379+379')
        self.assertIn(version_only(ROOT),src('lib/core/app_metadata.dart'))
