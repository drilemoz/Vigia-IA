import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/location_tracking_service.dart';
import 'package:vigiaia/services/map_gps_hud_policy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 23, 10);
  MapRoutePoint point(Duration age) => MapRoutePoint(
    latitude: -20.2,
    longitude: -45.7,
    recordedAt: now.subtract(age),
    accuracyMeters: 8,
    speedMetersPerSecond: 0,
  );

  test('GPS realmente desligado e permissão negada não são leitura antiga', () {
    expect(MapGpsHudPolicy.label(
      availability: LocationTrackingAvailability.servicesDisabled,
      point: point(const Duration(seconds: 3)), now: now,
    ), 'Localização desligada');
    expect(MapGpsHudPolicy.label(
      availability: LocationTrackingAvailability.permissionDenied,
      point: null, now: now,
    ), 'Sem permissão GPS');
  });

  test('posição recente parado continua GPS ativo', () {
    expect(MapGpsHudPolicy.label(
      availability: LocationTrackingAvailability.ready,
      point: point(const Duration(seconds: 15)), now: now,
    ), 'GPS ativo');
  });

  test('posição histórica não é confundida com GPS desligado', () {
    expect(MapGpsHudPolicy.label(
      availability: LocationTrackingAvailability.ready,
      point: point(const Duration(seconds: 38)), now: now,
    ), 'Leitura GPS antiga');
    expect(MapGpsHudPolicy.label(
      availability: LocationTrackingAvailability.ready,
      point: point(const Duration(minutes: 4)), now: now,
    ), 'Última posição: 4 min');
  });

  test('sem ponto mas com permissão mostra aguardo, não falha de hardware', () {
    expect(MapGpsHudPolicy.label(
      availability: LocationTrackingAvailability.ready,
      point: null, now: now,
    ), 'Aguardando posição');
  });
}
