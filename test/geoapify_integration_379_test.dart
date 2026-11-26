import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/services/geoapify_map_search_service.dart';
import 'package:vigiaia/services/geoapify_poi_service.dart';
import 'package:vigiaia/services/route_explorer_poi_provenance.dart';

void main() {
  final point = MapRoutePoint(latitude: -20, longitude: -45,
    recordedAt: DateTime.utc(2026, 11, 26), accuracyMeters: 0,
    speedMetersPerSecond: 0);
  test('reversa mantém coordenadas escolhidas, não as do endereço', () {
    final item = GeoapifyMapSearchService.decodeReverse(jsonEncode({
      'results': [{'lat': -20.001, 'lon': -45.001, 'formatted': 'Rua A, MG', 'city': 'Cidade A'}],
    }), point);
    expect(item, isNotNull);
    final result = item!;
    expect(result.latitude, point.latitude);
    expect(result.longitude, point.longitude);
    expect(result.source, 'geoapify');
    expect(result.subtitle, contains('Endereço aproximado'));
  });
  test('reversa vazia permite fallback', () {
    expect(GeoapifyMapSearchService.decodeReverse('{"results":[]}', point), isNull);
  });
  test('banheiro não aparece como água potável', () {
    final items = GeoapifyPoiService.decode(jsonEncode({'features': [
      {'geometry': {'coordinates': [-45, -20]}, 'properties': {
        'categories': ['amenity.toilet'], 'place_id': 't1',
      }},
      {'geometry': {'coordinates': [-45.01, -20]}, 'properties': {
        'categories': ['amenity.drinking_water'], 'place_id': 'w1',
      }},
    ]}), origin: point, enabled: {RouteExplorerCategory.water});
    expect(items, hasLength(2));
    expect(items.first.title, 'Banheiro mapeado');
    expect(items.first.amenities, ['Banheiro']);
    expect(items.last.amenities, contains('Água mapeada (potabilidade não verificada)'));
    expect(RouteExplorerPoiProvenance.sourceLabel(items.first.copyWith(source: 'cache')),
      'Cache local (Geoapify)');
  });
}
