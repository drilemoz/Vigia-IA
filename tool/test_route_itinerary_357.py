"""Regressões do itinerário offline 357; testes Dart reais rodam no CI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')

class RouteItinerary357(unittest.TestCase):
    def test_route_matcher_projects_and_sorts(self):
        src = read('lib/services/route_corridor_index.dart')
        for token in ('class RouteCorridorPlace', 'routeDistanceMeters:',
                      'proximityMeters:', 'located.sort(', 'maximumProximityMeters',
                      '_cumulative(simplified)', 'progress * scale'):
            self.assertIn(token, src)

    def test_sampling_uses_distance_not_vertex_index(self):
        src = read('lib/services/route_corridor_index.dart')
        self.assertIn('searchSamples(', src)
        self.assertIn('final goal = total * i / sections;', src)
        self.assertIn('maximumSamples = 25', src)
        self.assertIn('output.add(route.last)', src)

    def test_online_search_is_manual_and_bounded(self):
        src = read('lib/services/map_destination_search_service.dart')
        self.assertIn('RouteCorridorIndex.searchSamples(route)', src)
        self.assertIn('const batchSize = 6;', src)
        self.assertIn('HttpStatus.tooManyRequests', src)
        self.assertIn('await response.drain<void>()', src)
        self.assertIn('if (onlineAllowed)', src)
        self.assertIn('maximumResults: 100', src)

    def test_auto_local_without_gps_or_network(self):
        src = read('lib/screens/trip_planning_screen.dart')
        self.assertIn('localPlaces = await _citySearch.placesAlongRoute(', src)
        self.assertIn('onlineAllowed: false', src)
        self.assertIn('unawaited(_fillLocalPlaces(trip))', src)
        self.assertIn('unawaited(_fillLocalPlaces(next))', src)
        self.assertIn('unawaited(_fillLocalPlaces(initial))', src)
        self.assertIn('if (!mounted) return;', src)

    def test_cities_ordered_by_route_progress(self):
        src = read('lib/screens/trip_planning_screen.dart')
        self.assertIn('RouteCorridorIndex.locate(', src)
        self.assertIn('match.routeDistanceMeters / 1000', src)
        self.assertIn('match.proximityMeters.toStringAsFixed(0)', src)
        self.assertIn('Proximidade em linha reta', src)
        self.assertIn('match.place.latitude', src)

    def test_offline_poi_map_uses_corridor(self):
        src=read('lib/screens/trip_planning_screen.dart')
        segment=src.split('List<RouteExplorerResult> _offlinePoisOnRoute(',1)[1].split('List<RouteCorridorPlace> _nearbyRoutePlaces',1)[0]
        self.assertIn('RouteCorridorIndex.locate(', segment)
        self.assertIn('maximumProximityMeters: 2500', segment)

    def test_dart_regression_exists(self):
        src=read('test/route_corridor_index_test.dart')
        self.assertGreaterEqual(src.count("test('"), 4)
        self.assertIn('closeTo(22.2, 1)', src)

if __name__ == '__main__': unittest.main()
