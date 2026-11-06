import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/services/bike_trip_schedule.dart';
import 'package:vigiaia/services/trip_effort_reserve_service.dart';
import 'package:vigiaia/services/trip_terrain_service.dart';

void main() {
  const first = BikeTripDayPlan(
    day: 1, startDistanceMeters: 0, endDistanceMeters: 50000,
    ridingDuration: Duration(hours: 4), stopLabel: 'Parada estimada',
    stopLatitude: 0, stopLongitude: 0.5,
    stopKind: 'Não confirmado', usesKnownPlace: false,
  );
  const second = BikeTripDayPlan(
    day: 2, startDistanceMeters: 50000, endDistanceMeters: 100000,
    ridingDuration: Duration(hours: 4), stopLabel: 'Fim',
    stopLatitude: 0, stopLongitude: 1,
    stopKind: 'Destino', usesKnownPlace: true,
  );

  test('reserva só usa subidas em perfil alinhado e não extrapola lacunas', () {
    const route = MapCyclingRoute(
      points: [LatLng(0, 0), LatLng(0, 0.5), LatLng(0, 1)],
      distanceMeters: 100000, durationSeconds: 24000,
      elevationsMeters: [100, 300, 250],
    );
    final terrain = TripTerrainService.forDays(
      route: route, days: const [first, second]);
    expect(terrain[0].ascentMeters, closeTo(200, 1));
    expect(TripEffortReserveService.reserveMinutes(
        terrain: terrain.first, minutesPer100Meters: 10), 20);
    final scenario = TripEffortReserveService.adjustedDay(
      day: first, terrain: terrain.first, minutesPer100Meters: 10);
    expect(scenario.ridingDuration, const Duration(hours: 4, minutes: 20));
    expect(scenario.endDistanceMeters, first.endDistanceMeters);
    expect(TripEffortReserveService.adjustedDay(
        day: second, terrain: terrain.last, minutesPer100Meters: 10)
        .ridingDuration, second.ridingDuration);
    expect(TripEffortReserveService.adjustedDay(
        day: first, terrain: terrain.first, minutesPer100Meters: 0)
        .ridingDuration, first.ridingDuration);
    final missing = TripTerrainService.forDays(
      route: const MapCyclingRoute(
        points: [LatLng(0, 0), LatLng(0, 1)],
        distanceMeters: 100000, durationSeconds: 24000),
      days: const [first, second]);
    expect(TripEffortReserveService.reserveMinutes(
        terrain: missing.first, minutesPer100Meters: 20), 0);
  });

  test('avisos do dia usam duração simulada e limite pessoal de chegada', () {
    const terrain = TripDayTerrain(ascentMeters: 200, descentMeters: 0,
        coveredMeters: 50000, dayMeters: 50000);
    final adjusted = TripEffortReserveService.adjustedDay(
      day: first, terrain: terrain, minutesPer100Meters: 15);
    final schedule = BikeTripSchedule.forDay(
      day: adjusted, departureMinute: 16 * 60,
      breakEveryKm: 20, breakDurationMinutes: 10,
      lunchDurationMinutes: 0,
    );
    final notes = TripDayReadinessService.notices(
      day: adjusted, schedule: schedule, targetRidingHours: 4,
      latestArrivalMinute: 19 * 60, terrain: terrain,
      minutesPer100Meters: 15,
    );
    expect(notes.any((n) => n.contains('supera o limite')), isTrue);
    expect(notes.any((n) => n.contains('Chegada estimada depois')), isTrue);
    expect(notes.any((n) => n.contains('Pernoite não confirmado')), isTrue);
  });

  test('reserva parcial avisa cobertura e não extrapola altitude', () {
    const partial = TripDayTerrain(ascentMeters: 50, descentMeters: 0,
        coveredMeters: 15000, dayMeters: 50000);
    expect(TripEffortReserveService.reserveMinutes(
        terrain: partial, minutesPer100Meters: 10), 5);
    final messages = TripDayReadinessService.notices(
      day: first, schedule: BikeTripSchedule.forDay(day: first),
      targetRidingHours: 5, latestArrivalMinute: 20 * 60,
      terrain: partial, minutesPer100Meters: 10,
    );
    expect(messages.any((n) => n.contains('Perfil incompleto')), isTrue);
  });

  test('viagens antigas ficam neutras e novas opções persistem sem rede', () {
    MapDestinationSearchResult city(String id, double lon) =>
        MapDestinationSearchResult(id: id, title: id, subtitle: 'Local',
            latitude: 0, longitude: lon, distanceMeters: 0,
            kind: MapDestinationKind.city, source: 'saved');
    final trip = PlannedBikeTrip(id: 'offline', savedAt: DateTime.utc(2026, 11, 6),
      origin: city('Origem', 0), destination: city('Fim', 1),
      routes: const [MapCyclingRoute(points: [LatLng(0, 0), LatLng(0, 1)],
          distanceMeters: 100000, durationSeconds: 30000)],
      selectedIndex: 0, averageSpeedKmh: 15, ridingHoursPerDay: 5,
      departureMinute: 420, breakEveryKm: 20,
      breakMinutes: 10, lunchMinutes: 40);
    final old = trip.toJson()..remove('climbReserveMinutesPer100m')
      ..remove('latestArrivalMinute');
    final legacy = PlannedBikeTrip.fromJson(old);
    expect(legacy.climbReserveMinutesPer100m, 0);
    expect(legacy.latestArrivalMinute, 1080);
    final changed = legacy.copyWith(climbReserveMinutesPer100m: 10,
        latestArrivalMinute: 17 * 60);
    final restored = PlannedBikeTrip.fromJson(changed.toJson());
    expect(restored.climbReserveMinutesPer100m, 10);
    expect(restored.latestArrivalMinute, 17 * 60);
    final invalid = changed.toJson()..['latestArrivalMinute'] = -100;
    expect(PlannedBikeTrip.fromJson(invalid).latestArrivalMinute, 15 * 60);
    final malformed = changed.toJson()
      ..['latestArrivalMinute'] = 'inválido'
      ..['climbReserveMinutesPer100m'] = 'incompleto';
    final recovered = PlannedBikeTrip.fromJson(malformed);
    expect(recovered.latestArrivalMinute, 18 * 60);
    expect(recovered.climbReserveMinutesPer100m, 0);
  });
}
