import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/models/offline_map_package.dart';
import 'package:vigiaia/models/offline_poi_package.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/models/trip_stop_check.dart';
import 'package:vigiaia/services/trip_offline_readiness_service.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 12);
  MapDestinationSearchResult city(String id, double lon) =>
      MapDestinationSearchResult(
        id: id, title: id, subtitle: '', latitude: 0, longitude: lon,
        distanceMeters: 0, kind: MapDestinationKind.city, source: 'cache',
      );
  PlannedBikeTrip trip({List<TripStopCheck> checks = const []}) =>
      PlannedBikeTrip(
        id: '363', savedAt: now,
        origin: city('Origem', 0), destination: city('Destino', 1),
        routes: const <MapCyclingRoute>[
          MapCyclingRoute(
            points: <LatLng>[LatLng(0, 0), LatLng(0, 0.5), LatLng(0, 1)],
            distanceMeters: 120000, durationSeconds: 28800,
          ),
        ],
        selectedIndex: 0, averageSpeedKmh: 15, ridingHoursPerDay: 4,
        departureMinute: 420, breakEveryKm: 20,
        breakMinutes: 10, lunchMinutes: 40, stopChecks: checks,
      );
  const stage1 = BikeTripDayPlan(
    day: 1, startDistanceMeters: 0, endDistanceMeters: 60000,
    ridingDuration: Duration(hours: 4), stopLabel: 'Parada 1',
    stopLatitude: 0, stopLongitude: 0.5,
    stopKind: 'Parada', usesKnownPlace: false,
  );
  const stage2 = BikeTripDayPlan(
    day: 2, startDistanceMeters: 60000, endDistanceMeters: 120000,
    ridingDuration: Duration(hours: 4), stopLabel: 'Destino',
    stopLatitude: 0, stopLongitude: 1,
    stopKind: 'Destino', usesKnownPlace: true,
  );
  const plan = BikeTripPlan(
    estimate: BikeTripEstimate(
      distanceMeters: 120000, ridingDuration: Duration(hours: 8), dayCount: 2,
      preferences: BikeTravelPreferences(),
    ),
    days: <BikeTripDayPlan>[stage1, stage2],
  );
  OfflineMapPackage map(String id, {double? west, double? east,
      DateTime? expiresAt}) => OfflineMapPackage(
    id: id, name: id, path: '/local/$id.mbtiles', sizeBytes: 3000,
    addedAt: now, west: west, east: east,
    south: west == null ? null : -0.2,
    north: west == null ? null : 0.2,
    expiresAt: expiresAt,
  );
  TripStopCheck stop({bool overnight = false, double lon = 0.5}) =>
      TripStopCheck(
        day: 1, routeIndex: 0, endDistanceMeters: 60000,
        latitude: 0, longitude: lon, checkedAt: now,
        waterChecked: true, overnightChecked: overnight,
      );

  test('sem arquivos: não declara prontidão e não inventa cobertura', () async {
    final report = await TripOfflineReadinessService.inspect(
      trip: trip(), plan: plan,
      offlineMaps: const [], offlinePoiPackages: const [], now: now,
    );
    expect(report.availableMaps, 0);
    expect(report.samplesWithinMapBounds, 0);
    expect(report.samplesOutsideAvailableBounds, report.routeSamples);
    expect(report.intermediateStopsWithoutOvernightCheck, 1);
    expect(report.needsReview, isTrue);
  });

  test('união dos limites de dois arquivos cobre amostras, não tiles', () async {
    final report = await TripOfflineReadinessService.inspect(
      trip: trip(), plan: plan,
      offlineMaps: [map('oeste', west: -0.1, east: 0.5),
        map('leste', west: 0.5, east: 1.1)],
      offlinePoiPackages: const [], now: now,
      mapProbe: (value) async => true,
    );
    expect(report.availableMaps, 2);
    expect(report.samplesWithinMapBounds, report.routeSamples);
    expect(report.samplesOutsideAvailableBounds, 0);
    expect(report.samplesWithUnknownCoverage, 0);
  });

  test('arquivo registrado mas desaparecido não oferece cobertura', () async {
    final report = await TripOfflineReadinessService.inspect(
      trip: trip(), plan: plan,
      offlineMaps: [map('inexistente', west: -1, east: 2)],
      offlinePoiPackages: const [], now: now,
      mapProbe: (value) async => false,
    );
    expect(report.availableMaps, 0);
    expect(report.missingMapFiles, 1);
    expect(report.samplesWithinMapBounds, 0);
    expect(report.daysOutsideMapBounds, contains(1));
  });

  test('MBTiles sem bounds não é assumido como cobertura confirmada', () async {
    final report = await TripOfflineReadinessService.inspect(
      trip: trip(), plan: plan, offlineMaps: [map('sem-limites')],
      offlinePoiPackages: const [], now: now,
      mapProbe: (value) async => true,
    );
    expect(report.samplesWithinMapBounds, 0);
    expect(report.samplesWithUnknownCoverage, report.routeSamples);
    expect(report.mapsWithoutBounds, 1);
  });

  test('limites invertidos não são tratados como cobertura confiável', () async {
    final report = await TripOfflineReadinessService.inspect(
      trip: trip(), plan: plan,
      offlineMaps: [map('inválido', west: 1, east: 0)],
      offlinePoiPackages: const [], now: now,
      mapProbe: (value) async => true,
    );
    expect(report.samplesWithinMapBounds, 0);
    expect(report.samplesWithUnknownCoverage, report.routeSamples);
  });

  test('conferência desatualizada não conta como pernoite confirmado', () async {
    final stale = await TripOfflineReadinessService.inspect(
      trip: trip(checks: [stop(overnight: true, lon: 0.55)]),
      plan: plan, offlineMaps: const [], offlinePoiPackages: const [], now: now,
    );
    expect(stale.intermediateStopsWithoutOvernightCheck, 1);
    expect(stale.stagesWithManualChecks, 0);
    final valid = await TripOfflineReadinessService.inspect(
      trip: trip(checks: [stop(overnight: true)]),
      plan: plan, offlineMaps: const [], offlinePoiPackages: const [], now: now,
    );
    expect(valid.intermediateStopsWithoutOvernightCheck, 0);
    expect(valid.stagesWithManualChecks, 1);
  });

  test('conta ponto de apoio persistido realmente próximo do corredor', () async {
    final item = RouteExplorerResult(
      id: 'agua', category: RouteExplorerCategory.water,
      title: 'Água', subtitle: '', latitude: 0.001, longitude: 0.5,
      distanceMeters: 0,
    );
    final package = OfflinePoiPackage(
      id: 'apoios', name: 'Apoios', createdAt: now, updatedAt: now,
      west: 0, east: 1, south: -0.1, north: 0.1,
      originLatitude: 0, originLongitude: 0.5, searchRadiusKm: 10,
      items: [item],
    );
    final report = await TripOfflineReadinessService.inspect(
      trip: trip(), plan: plan, offlineMaps: const [],
      offlinePoiPackages: [package], now: now,
    );
    expect(report.offlinePoiPackages, 1);
    expect(report.offlinePoisNearRoute, 1);
  });

  test('arquivo expirado é marcado sem apagar mapa local', () async {
    final report = await TripOfflineReadinessService.inspect(
      trip: trip(), plan: plan,
      offlineMaps: [map('antigo', west: -1, east: 2,
        expiresAt: DateTime.utc(2026, 11, 1))],
      offlinePoiPackages: const [], now: now,
      mapProbe: (value) async => true,
    );
    expect(report.availableMaps, 1);
    expect(report.mapsNeedingRefresh, 1);
    expect(report.needsReview, isTrue);
  });
}
