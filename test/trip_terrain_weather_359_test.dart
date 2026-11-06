import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_navigation_target.dart';
import 'package:vigiaia/models/trip_weather_day_forecast.dart';
import 'package:vigiaia/services/map_cycling_route_service.dart';
import 'package:vigiaia/services/saved_bike_route_service.dart';
import 'package:vigiaia/services/trip_terrain_service.dart';

void main() {
  test('ORS preserva altitude alinhada e resumo de ganho e perda', () {
    final route = MapCyclingRouteService().parseOrsGeoJson('''
      {"features":[{"geometry":{"coordinates":[[0,0,100],
      [0.5,0,200],[1,0,150]]},"properties":{"summary":
      {"distance":111200,"duration":30000,"ascent":100,"descent":50}}}]}
    ''');
    expect(route.elevationsMeters, [100, 200, 150]);
    expect(route.ascentMeters, 100);
    expect(route.descentMeters, 50);
  });

  test('salvar rota mantém elevação e aceita formato antigo sem inventar dados', () {
    final value = SavedBikeRoute(
      target: MapNavigationTarget(latitude: 0, longitude: 1,
          label: 'Fim', startedAt: DateTime.utc(2026, 11, 5)),
      routes: const [MapCyclingRoute(
        points: [LatLng(0, 0), LatLng(0, 0.5), LatLng(0, 1)],
        distanceMeters: 111200, durationSeconds: 12000,
        ascentMeters: 100, descentMeters: 50,
        elevationsMeters: [100, 200, 150],
      )], selectedIndex: 0,
    );
    final json = SavedBikeRouteService.encode(value);
    final route = SavedBikeRouteService.decode(json).routes.single;
    expect(route.ascentMeters, 100);
    expect(route.descentMeters, 50);
    expect(route.elevationsMeters, [100, 200, 150]);
    final older = SavedBikeRouteService.encode(value);
    final raw = ((older['routes'] as List).single as Map<String, Object?>);
    raw.remove('ascentMeters');
    raw.remove('descentMeters');
    raw.remove('elevationsMeters');
    final oldRoute = SavedBikeRouteService.decode(older).routes.single;
    expect(oldRoute.ascentMeters, isNull);
    expect(oldRoute.elevationsMeters, isEmpty);
  });

  test('relevo por dia só usa amostras reais alinhadas', () {
    const route = MapCyclingRoute(
      points: [LatLng(0, 0), LatLng(0, 0.5), LatLng(0, 1)],
      distanceMeters: 100000, durationSeconds: 25000,
      elevationsMeters: [100, 300, 200],
    );
    const days = <BikeTripDayPlan>[
      BikeTripDayPlan(day: 1, startDistanceMeters: 0,
        endDistanceMeters: 50000, ridingDuration: Duration(hours: 4),
        stopLabel: 'Parada', stopLatitude: 0, stopLongitude: 0.5,
        stopKind: 'Ponto', usesKnownPlace: true),
      BikeTripDayPlan(day: 2, startDistanceMeters: 50000,
        endDistanceMeters: 100000, ridingDuration: Duration(hours: 4),
        stopLabel: 'Fim', stopLatitude: 0, stopLongitude: 1,
        stopKind: 'Destino', usesKnownPlace: true),
    ];
    final stats = TripTerrainService.forDays(route: route, days: days);
    expect(stats.first.ascentMeters, closeTo(200, 1));
    expect(stats.first.descentMeters, closeTo(0, 1));
    expect(stats.last.descentMeters, closeTo(100, 1));
    expect(stats.last.coverageFraction, closeTo(1, 0.01));
    final missing = TripTerrainService.forDays(
      route: const MapCyclingRoute(
        points: [LatLng(0, 0), LatLng(0, 1)],
        distanceMeters: 100000, durationSeconds: 25000), days: days,
    );
    expect(missing.first.hasSamples, isFalse);
  });

  test('previsão pontual com carimbo de hora serializa sem inferir zeros', () {
    final sample = TripWeatherDayForecast(day: 2,
      estimatedAt: DateTime.utc(2026, 11, 8, 14),
      updatedAt: DateTime.utc(2026, 11, 5, 10),
      rainProbabilityPercent: 75, windGustKmh: 45);
    final restored = TripWeatherDayForecast.fromJson(
      Map<String, dynamic>.from(sample.toJson()));
    expect(restored.day, 2);
    expect(restored.rainProbabilityPercent, 75);
    expect(restored.windGustKmh, 45);
    expect(restored.precipitationMm, isNull);
    expect(restored.estimatedAt.isUtc, isTrue);
    expect(() => TripWeatherDayForecast.fromJson({'day': -1}),
        throwsFormatException);
  });
}
