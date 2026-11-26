import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(name): return (ROOT / name).read_text(encoding='utf-8')
class GpsSurfaceApi377(unittest.TestCase):
    def test_endpoint_and_fallback(self):
        for path in ['lib/services/partner_api_key_service.dart','lib/services/map_cycling_route_service.dart']:
            s = read(path)
            self.assertIn('api.heigit.org', s)
            self.assertIn('/openrouteservice/v2/directions/', s)
            self.assertNotIn('api.openrouteservice.org', s)
        route = read('lib/services/map_cycling_route_service.dart')
        for token in ['extra_info', 'alternative_routes', 'parseGeoapifyRoutes', 'avoid_bad_surfaces', 'rankSurfaceRoutes']:
            self.assertIn(token, route)
    def test_shared_preferences(self):
        for path in ['lib/screens/trip_planning_screen.dart','lib/screens/map_monitoring_screen.dart']:
            self.assertIn('chooseBikeSurface(context)', read(path))
        self.assertIn("'bikeSurface': _bikeSurface.name", read('lib/services/map_view_settings_service.dart'))
    def test_gps(self):
        self.assertIn('timeLimit: Duration(seconds: 20)', read('lib/services/location_tracking_service.dart'))
        self.assertIn('Timer.periodic', read('lib/services/map_route_service.dart'))
        self.assertIn('onDone: _scheduleGpsRetry', read('lib/services/map_route_service.dart'))
