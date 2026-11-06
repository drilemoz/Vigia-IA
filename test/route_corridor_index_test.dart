import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/services/route_corridor_index.dart';

void main() {
  MapDestinationSearchResult city(String id, double longitude, {double latitude = 0}) =>
      MapDestinationSearchResult(
        id: id,
        title: id,
        subtitle: 'Cidade de teste',
        latitude: latitude,
        longitude: longitude,
        distanceMeters: 0,
        kind: MapDestinationKind.town,
        source: 'offline',
      );

  test('Localidades offline aparecem na ordem do trajeto, não do cadastro', () {
    final results = RouteCorridorIndex.locate(
      route: const <LatLng>[
        LatLng(0, 0), LatLng(0, 0.5), LatLng(0, 1),
      ],
      routeDistanceMeters: 111200,
      places: <MapDestinationSearchResult>[
        city('final', 0.8),
        city('inicio', 0.2),
        city('fora', 0.3, latitude: 0.08),
        city('meio', 0.5),
      ],
    );
    expect(results.map((e) => e.place.id), <String>['inicio', 'meio', 'final']);
    expect(results.first.routeDistanceMeters / 1000, closeTo(22.2, 1));
    expect(results.last.routeDistanceMeters / 1000, closeTo(89.0, 1));
  });

  test('Projeção localiza uma cidade sobre um segmento sem vértice intermediário', () {
    final matches = RouteCorridorIndex.locate(
      route: const <LatLng>[LatLng(0, 0), LatLng(0, 1)],
      routeDistanceMeters: 111200,
      places: <MapDestinationSearchResult>[city('meio da estrada', 0.5)],
    );
    expect(matches, hasLength(1));
    expect(matches.first.proximityMeters, lessThan(1));
  });

  test('Amostragem por distância inclui início, meio e fim, com teto', () {
    final route = const <LatLng>[LatLng(0, 0), LatLng(0, 6.4)];
    final samples = RouteCorridorIndex.searchSamples(route);
    expect(samples.first, route.first);
    expect(samples.last, route.last);
    expect(samples.length, greaterThan(8));
    expect(samples.length, lessThanOrEqualTo(25));
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i].longitude, greaterThan(samples[i - 1].longitude));
    }
  });

  test('Rota degenerada, duplicidades e coordenadas inválidas são seguras', () {
    final empty = RouteCorridorIndex.locate(
      route: const <LatLng>[LatLng(0, 0), LatLng(0, 0)],
      routeDistanceMeters: 0,
      places: <MapDestinationSearchResult>[city('A', 0)],
    );
    expect(empty, isEmpty);
    final once = RouteCorridorIndex.locate(
      route: const <LatLng>[LatLng(0, 0), LatLng(0, 1)],
      routeDistanceMeters: 0,
      places: <MapDestinationSearchResult>[city('A', 0.25), city('A', 0.25)],
    );
    expect(once, hasLength(1));
    expect(once.first.routeDistanceMeters, greaterThan(20000));
  });
}
