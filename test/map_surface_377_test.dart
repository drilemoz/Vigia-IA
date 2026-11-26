import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_cycling_route_service.dart';
import 'package:vigiaia/services/map_view_settings_service.dart';

void main() {
  test('ORS: múltiplas alternativas e pavimento desconhecido', () {
    final service = MapCyclingRouteService();
    final routes = service.parseOrsAlternatives(jsonEncode({'features': [
      for (final surface in [11, 3]) {'geometry': {'coordinates': [[-45.0,-20.0],[-45.1,-20.1]]},
        'properties': {'summary': {'distance': 1000, 'duration': 100},
          'extras': {'surface': {'summary': [{'value': surface, 'distance': 800}]}}}},
    ]}));
    expect(routes, hasLength(2));
    expect(routes.first.unpavedMeters, 800);
    expect(routes.last.pavedMeters, 800);
    expect(routes.last.unknownSurfaceMeters, 200);
    expect(MapCyclingRouteService.rankSurfaceRoutes(routes, BikeSurfacePreference.rain), [routes.last]);
    expect(MapCyclingRouteService.rankSurfaceRoutes(routes, BikeSurfacePreference.paved).first, routes.last);
  });
  test('Geoapify: superfície e geometria de uma perna', () {
    final routes = MapCyclingRouteService().parseGeoapifyRoutes(jsonEncode({'features': [
      {'geometry': {'coordinates': [[[-45.0,-20.0],[-45.1,-20.1]]]},
       'properties': {'distance': 1000, 'time': 120, 'legs': [{'steps': [
         {'distance': 700, 'surface': 'paved_smooth'}, {'distance': 200, 'surface': 'dirt'},
       ]}]}},
    ]}));
    expect(routes.single.points.first.latitude, -20);
    expect(routes.single.pavedMeters, 700);
    expect(routes.single.unpavedMeters, 200);
    expect(routes.single.unknownSurfaceMeters, 100);
  });
}
