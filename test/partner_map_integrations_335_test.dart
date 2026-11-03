import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/services/geoapify_map_search_service.dart';
import 'package:vigiaia/services/geoapify_poi_service.dart';
import 'package:vigiaia/services/map_cycling_route_service.dart';
import 'package:vigiaia/services/map_weather_service.dart';

void main() {
  final origin = MapRoutePoint(
    latitude: -18.58,
    longitude: -46.52,
    recordedAt: DateTime.utc(2026, 11, 3),
    accuracyMeters: 0,
    speedMetersPerSecond: 0,
  );

  test('Geoapify geocodifica cidade sem perder longitude/latitude', () {
    final results = GeoapifyMapSearchService.decodeResponse(jsonEncode({
      'results': [
        {'lat': -18.578, 'lon': -46.519, 'result_type': 'city',
         'name': 'Patos de Minas', 'formatted': 'Patos de Minas, MG, Brasil',
         'place_id': 'city-1'},
        {'lat': 999, 'lon': 1, 'name': 'invalido'},
      ],
    }), origin);
    expect(results, hasLength(1));
    expect(results.single.title, 'Patos de Minas');
    expect(results.single.latitude, closeTo(-18.578, 0.00001));
    expect(results.single.longitude, closeTo(-46.519, 0.00001));
    expect(results.single.id, 'geoapify:city-1');
  });

  test('Geoapify Places respeita categorias e calcula distancia em metros', () {
    final results = GeoapifyPoiService.decode(jsonEncode({
      'features': [
        {'geometry': {'coordinates': [-46.52, -18.58]},
         'properties': {'name': 'Posto exemplo', 'place_id': 'poi-1',
           'categories': ['service.vehicle.fuel']}},
        {'geometry': {'coordinates': [-46.52, -18.58]},
         'properties': {'name': 'Restaurante exemplo', 'place_id': 'poi-2',
           'categories': ['catering.restaurant']}},
      ],
    }), origin: origin, enabled: {RouteExplorerCategory.fuel});
    expect(results, hasLength(1));
    expect(results.single.category, RouteExplorerCategory.fuel);
    expect(results.single.distanceMeters, closeTo(0, 0.1));
  });

  test('ORS GeoJSON importa rota, manobras e desníveis', () {
    final route = MapCyclingRouteService().parseOrsGeoJson(jsonEncode({
      'features': [
        {
          'geometry': {'coordinates': [
            [-46.52, -18.58, 820], [-46.51, -18.57, 850],
          ]},
          'properties': {
            'summary': {'distance': 1700, 'duration': 430,
                        'ascent': 35, 'descent': 6},
            'segments': [
              {'steps': [
                {'way_points': [0, 1], 'instruction': 'Continue',
                 'distance': 1700, 'duration': 430, 'type': 0},
              ]},
            ],
          },
        },
      ],
    }));
    expect(route.points, hasLength(2));
    expect(route.points.first.latitude, closeTo(-18.58, 0.00001));
    expect(route.ascentMeters, 35);
    expect(route.descentMeters, 6);
    expect(route.maneuvers.single.instruction, 'Continue');
  });

  test('Open-Meteo preserva UV e radiação horária no cache', () {
    final weather = MapWeatherService.decodeOnlineResponse({
      'current': {'time': '2026-11-03T12:00', 'temperature_2m': 28},
      'hourly': {
        'time': ['2026-11-03T12:00'],
        'uv_index': [7.6],
        'shortwave_radiation': [520],
      },
    }, latitude: -18.58, longitude: -46.52,
        receivedAt: DateTime.utc(2026, 11, 3, 12));
    expect(weather.hourlyForecast, hasLength(1));
    expect(weather.hourlyForecast.single.uvIndex, 7.6);
    expect(weather.hourlyForecast.single.shortwaveRadiationWm2, 520);
  });
}
