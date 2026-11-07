import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/models/trip_stop_check.dart';
import 'package:vigiaia/services/bike_trip_schedule.dart';
import 'package:vigiaia/services/trip_effort_reserve_service.dart';
import 'package:vigiaia/services/trip_terrain_service.dart';

void main() {
  const stage = BikeTripDayPlan(
    day: 1,
    startDistanceMeters: 0,
    endDistanceMeters: 50000,
    ridingDuration: Duration(hours: 4),
    stopLabel: 'Parada na estrada',
    stopLatitude: -20.1,
    stopLongitude: -45.1,
    stopKind: 'Parada',
    usesKnownPlace: false,
  );

  TripStopCheck check({
    double latitude = -20.1,
    int routeIndex = 0,
    String notes = 'Confirmado por telefone',
  }) => TripStopCheck(
    day: 1,
    routeIndex: routeIndex,
    endDistanceMeters: 50000,
    latitude: latitude,
    longitude: -45.1,
    checkedAt: DateTime.utc(2026, 11, 6, 12),
    accessChecked: true,
    waterChecked: true,
    notes: notes,
  );

  MapDestinationSearchResult city(String id, double longitude) =>
      MapDestinationSearchResult(
        id: id, title: id, subtitle: '',
        latitude: -20.1, longitude: longitude, distanceMeters: 0,
        kind: MapDestinationKind.city, source: 'cache',
      );

  PlannedBikeTrip trip({List<TripStopCheck> checks = const []}) =>
      PlannedBikeTrip(
        id: '362', savedAt: DateTime.utc(2026, 11, 6),
        origin: city('Origem', -45.5), destination: city('Fim', -44.5),
        routes: const [MapCyclingRoute(
          points: [LatLng(-20.1, -45.5), LatLng(-20.1, -44.5)],
          distanceMeters: 100000, durationSeconds: 24000,
        )],
        selectedIndex: 0, averageSpeedKmh: 15, ridingHoursPerDay: 5,
        departureMinute: 420, breakEveryKm: 20,
        breakMinutes: 10, lunchMinutes: 40,
        stopChecks: checks,
      );

  test('conferência não presume pernoite a partir de água e acesso', () {
    final saved = check();
    expect(saved.hasDetails, isTrue);
    expect(saved.accessChecked, isTrue);
    expect(saved.waterChecked, isTrue);
    expect(saved.overnightChecked, isFalse);
  });

  test('coordenada ou alternativa distinta invalida conferência', () {
    expect(check().matches(stage: stage, selectedRouteIndex: 0), isTrue);
    expect(check().matches(stage: stage, selectedRouteIndex: 1), isFalse);
    expect(check(routeIndex: 1).matches(stage: stage, selectedRouteIndex: 0), isFalse);
    expect(check(latitude: -20.11).matches(stage: stage, selectedRouteIndex: 0), isFalse);
    final moved = BikeTripDayPlan(
      day: 1, startDistanceMeters: 0, endDistanceMeters: 53000,
      ridingDuration: const Duration(hours: 4),
      stopLabel: 'Outra etapa', stopLatitude: -20.1, stopLongitude: -45.1,
      stopKind: 'Parada', usesKnownPlace: false,
    );
    expect(check().matches(stage: moved, selectedRouteIndex: 0), isFalse);
  });

  test('viagem salva persiste notas e conferências sem rede', () {
    final saved = trip(checks: [check()]);
    final restored = PlannedBikeTrip.fromJson(saved.toJson());
    expect(restored.stopChecks, hasLength(1));
    expect(restored.stopChecks.single.notes, 'Confirmado por telefone');
    expect(restored.stopChecks.single.matches(stage: stage, selectedRouteIndex: 0), isTrue);
    expect(restored.selectedRoute.distanceMeters, 100000);
  });

  test('aviso de pernoite respeita apenas conferência manual válida', () {
    const terrain = TripDayTerrain(ascentMeters: 0, descentMeters: 0,
        coveredMeters: 0, dayMeters: 50000);
    final schedule = BikeTripSchedule.forDay(day: stage);
    List<String> notices({bool verified = false}) =>
        TripDayReadinessService.notices(
          day: stage, schedule: schedule,
          targetRidingHours: 5, latestArrivalMinute: 20 * 60,
          terrain: terrain, minutesPer100Meters: 0,
          overnightManuallyChecked: verified,
        );
    expect(notices().any((value) => value.contains('Pernoite não confirmado')), isTrue);
    final saved = check();
    expect(saved.overnightChecked, isFalse);
    final withOvernight = TripStopCheck.fromJson({
      ...saved.toJson(), 'overnightChecked': true,
    });
    expect(withOvernight.matches(stage: stage, selectedRouteIndex: 0), isTrue);
    expect(notices(verified: withOvernight.overnightChecked)
        .any((value) => value.contains('Pernoite não confirmado')), isFalse);
    expect(withOvernight.matches(stage: stage, selectedRouteIndex: 1), isFalse);
  });

  test('JSON antigo sem campo continua abrindo com lista vazia', () {
    final raw = trip().toJson()..remove('stopChecks');
    expect(PlannedBikeTrip.fromJson(raw).stopChecks, isEmpty);
  });

  test('uma anotação corrompida é descartada sem perder a rota', () {
    final raw = trip(checks: [check()]).toJson();
    raw['stopChecks'] = [
      {'day': 2, 'latitude': 900, 'longitude': 0},
      check().toJson(),
      'inválido',
    ];
    final restored = PlannedBikeTrip.fromJson(raw);
    expect(restored.stopChecks, hasLength(1));
    expect(restored.selectedRoute.distanceMeters, 100000);
  });

  test('notas excessivas são limitadas sem apagar a informação restante', () {
    final restored = TripStopCheck.fromJson({
      ...check().toJson(), 'notes': List<String>.filled(700, 'a').join(),
    });
    expect(restored.notes.length, 500);
    expect(restored.accessChecked, isTrue);
  });
}
