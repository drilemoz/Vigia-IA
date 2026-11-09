import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/services/bike_trip_planner.dart';
import 'package:vigiaia/services/trip_distance_goal_safety.dart';

void main() {
  const planner = BikeTripPlanner();
  const route = <LatLng>[LatLng(0, 0), LatLng(0, 0.9)];

  BikeTripPlan routeWithPlace({required double goal, required double stopKm,
      bool firstOnly = false}) => planner.buildPlan(
    routePoints: route,
    routeDistanceMeters: 100000,
    preferences: const BikeTravelPreferences(
      averageSpeedKmh: 20, ridingHoursPerDay: 5, balanceDays: false),
    destinationLabel: 'Destino',
    candidates: [MapDestinationSearchResult(
      id: 'apoio', title: 'Apoio candidato', subtitle: 'Não confirmado',
      latitude: 0, longitude: stopKm / 100 * 0.9,
      distanceMeters: 0,
      kind: MapDestinationKind.city, source: 'offline',
    )],
    dailyDistanceTargetKm: goal,
    distanceGoalFirstDayOnly: firstOnly,
  );

  void expectMonotonic(BikeTripPlan plan) {
    expect(plan.days, isNotEmpty);
    var previous = 0.0;
    for (final day in plan.days) {
      expect(day.startDistanceMeters, closeTo(previous, 0.01));
      expect(day.distanceMeters, greaterThan(0));
      expect(day.endDistanceMeters, greaterThan(previous));
      previous = day.endDistanceMeters;
    }
    expect(previous, closeTo(100000, 0.01));
  }

  test('local no km 20 nao cria retorno depois da meta de 5 km', () {
    final plan = routeWithPlace(goal: 5, stopKm: 20);
    expect(plan.days, hasLength(20));
    expectMonotonic(plan);
    expect(plan.days.first.endDistanceMeters, closeTo(5000, 0.1));
    expect(plan.days.first.usesKnownPlace, isFalse);
  });

  test('candidato adiantado ainda preserva deslocamento de todos os dias', () {
    final plan = routeWithPlace(goal: 20, stopKm: 26);
    expect(plan.days, hasLength(5));
    expectMonotonic(plan);
    for (final day in plan.days) {
      expect(day.ridingDuration.inMinutes, lessThanOrEqualTo(300));
    }
  });

  test('meta apenas do primeiro dia nao puxa apoio distante', () {
    final plan = routeWithPlace(goal: 5, stopKm: 20, firstOnly: true);
    expectMonotonic(plan);
    expect(plan.days.first.distanceMeters, closeTo(5000, 0.1));
  });

  test('bloqueia meta que excede horas de pedal', () {
    final error = TripDistanceGoalSafety.validate(
      distanceKm: 300, averageSpeedKmh: 5, maxRidingHoursPerDay: 12,
      departureMinute: 420, latestArrivalMinute: 1260,
      breakEveryKm: 20, breakMinutes: 10,
      lunchMinutes: 40, forceLunch: false,
    );
    expect(error, contains('acima do limite'));
  });

  test('bloqueia chegada tardia incluindo pausas e almoço', () {
    final error = TripDistanceGoalSafety.validate(
      distanceKm: 50, averageSpeedKmh: 20, maxRidingHoursPerDay: 5,
      departureMinute: 16 * 60, latestArrivalMinute: 18 * 60,
      breakEveryKm: 20, breakMinutes: 10,
      lunchMinutes: 40, forceLunch: false,
    );
    expect(error, contains('depois do limite'));
  });

  test('aceita percurso viavel com horario e margem de pedal', () {
    final error = TripDistanceGoalSafety.validate(
      distanceKm: 50, averageSpeedKmh: 20, maxRidingHoursPerDay: 5,
      departureMinute: 7 * 60, latestArrivalMinute: 18 * 60,
      breakEveryKm: 20, breakMinutes: 10,
      lunchMinutes: 40, forceLunch: false,
    );
    expect(error, isNull);
  });

  test('valida entradas invalidas sem aceitar NaN', () {
    final error = TripDistanceGoalSafety.validate(
      distanceKm: double.nan, averageSpeedKmh: 20,
      maxRidingHoursPerDay: 5, departureMinute: 420,
      latestArrivalMinute: 1080, breakEveryKm: 20,
      breakMinutes: 10, lunchMinutes: 40, forceLunch: false,
    );
    expect(error, isNotNull);
  });
}
