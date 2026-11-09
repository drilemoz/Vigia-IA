import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/services/bike_trip_planner.dart';

void main() {
  const planner = BikeTripPlanner();
  const route = <LatLng>[LatLng(0, 0), LatLng(0, 2.0)];

  BikeTripPlan plan({double? goal, bool firstOnly = true,
      double meters = 250000, bool balance = true}) => planner.buildPlan(
    routePoints: route, routeDistanceMeters: meters,
    preferences: BikeTravelPreferences(
      averageSpeedKmh: 20, ridingHoursPerDay: 5, balanceDays: balance,
    ),
    destinationLabel: 'Destino', candidates: const [],
    dailyDistanceTargetKm: goal,
    distanceGoalFirstDayOnly: firstOnly,
  );

  test('viagens antigas preservam os dias baseados em horas', () {
    final previous = plan();
    expect(previous.days, hasLength(3));
    expect(previous.days.first.distanceMeters, closeTo(250000 / 3, 1));
  });

  test('primeiro dia aceita 50 km e seguintes usam as 5 horas padrão', () {
    final result = plan(goal: 50);
    expect(result.days, hasLength(3));
    expect(result.days.first.distanceMeters, closeTo(50000, 1));
    expect(result.days[1].distanceMeters, closeTo(100000, 1));
    expect(result.days.last.endDistanceMeters, 250000);
    expect(result.days[1].startDistanceMeters, result.days.first.endDistanceMeters);
  });

  test('meta de 50 km para todos os dias não excede meta equilibrada', () {
    final result = plan(goal: 50, firstOnly: false, meters: 230000);
    expect(result.days, hasLength(5));
    for (final day in result.days) {
      expect(day.distanceMeters, closeTo(46000, 1));
    }
    expect(result.days.last.endDistanceMeters, 230000);
  });

  test('sem equilíbrio mantém 50 km e último dia menor', () {
    final result = plan(goal: 50, firstOnly: false,
        meters: 230000, balance: false);
    expect(result.days, hasLength(5));
    expect(result.days.first.distanceMeters, closeTo(50000, 1));
    expect(result.days.last.distanceMeters, closeTo(30000, 1));
  });

  test('meta inválida não substitui o modo antigo', () {
    expect(plan(goal: 0).days.length, plan().days.length);
    expect(plan(goal: double.nan).days.length, plan().days.length);
  });

  test('meta de distância persiste sem quebrar viagens anteriores', () {
    const start = MapDestinationSearchResult(
      id: 'start', title: 'Partida', subtitle: '', latitude: 0, longitude: 0,
      distanceMeters: 0, kind: MapDestinationKind.city, source: 'offline');
    const destination = MapDestinationSearchResult(
      id: 'destination', title: 'Destino', subtitle: '', latitude: 0, longitude: 2,
      distanceMeters: 0, kind: MapDestinationKind.city, source: 'offline');
    final trip = PlannedBikeTrip(
      id: '374', savedAt: DateTime(2026, 11, 9),
      origin: start, destination: destination,
      routes: const [MapCyclingRoute(points: route,
        distanceMeters: 250000, durationSeconds: 45000)],
      selectedIndex: 0, averageSpeedKmh: 20, ridingHoursPerDay: 5,
      departureMinute: 420, breakEveryKm: 20, breakMinutes: 10,
      lunchMinutes: 40, dailyDistanceTargetKm: 50,
      distanceGoalFirstDayOnly: true,
    );
    final restored = PlannedBikeTrip.fromJson(trip.toJson());
    expect(restored.dailyDistanceTargetKm, 50);
    expect(restored.distanceGoalFirstDayOnly, true);
    expect(restored.copyWith(clearDailyDistanceTarget: true).dailyDistanceTargetKm, isNull);
    final legacy = trip.toJson()
      ..remove('dailyDistanceTargetKm')
      ..remove('distanceGoalFirstDayOnly');
    expect(PlannedBikeTrip.fromJson(legacy).dailyDistanceTargetKm, isNull);
    expect(PlannedBikeTrip.fromJson(legacy).distanceGoalFirstDayOnly, true);
    final invalid = trip.toJson()..['dailyDistanceTargetKm'] = -10;
    expect(PlannedBikeTrip.fromJson(invalid).dailyDistanceTargetKm, isNull);
  });
}
