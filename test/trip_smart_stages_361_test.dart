import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/services/bike_trip_planner.dart';
import 'package:vigiaia/services/trip_stage_effort_profile.dart';

void main() {
  const routePoints = <LatLng>[
    LatLng(0, 0), LatLng(0, 0.30), LatLng(0, 0.60),
  ];
  const prefs = BikeTravelPreferences(
    averageSpeedKmh: 15, ridingHoursPerDay: 2, balanceDays: true,
  );
  const planner = BikeTripPlanner();

  BikeTripPlan build({
    bool smart = true,
    List<double?> heights = const <double?>[100, 400, 400],
    int reserve = 10,
    List<MapDestinationSearchResult> candidates =
        const <MapDestinationSearchResult>[],
  }) => planner.buildPlan(
    routePoints: routePoints,
    routeDistanceMeters: 60000,
    preferences: prefs,
    destinationLabel: 'Fim',
    candidates: candidates,
    elevationsMeters: heights,
    climbReserveMinutesPer100m: reserve,
    smartStages: smart,
  );

  test('reserva de subida documentada aumenta quantidade de etapas', () {
    final traditional = build(smart: false);
    final optimized = build();
    expect(traditional.estimate.dayCount, 2);
    expect(optimized.estimate.dayCount, 3);
    expect(optimized.days, hasLength(3));
    expect(optimized.days.first.endDistanceMeters,
        lessThan(traditional.days.first.endDistanceMeters));
    expect(optimized.days.last.endDistanceMeters, 60000);
    expect(optimized.days.last.stopLabel, 'Fim');
  });

  test('sem perfil ou sem reserva mantém número de dias de base', () {
    expect(build(heights: const <double?>[]).estimate.dayCount, 2);
    expect(build(heights: const <double?>[100, null, 400])
        .estimate.dayCount, 2);
    expect(build(reserve: 0).estimate.dayCount, 2);
  });

  test('índice de esforço soma apenas subida com amostras alinhadas', () {
    final profile = TripStageEffortProfile.fromRoute(
      points: routePoints,
      routeDistanceMeters: 60000,
      averageSpeedKmh: 15,
      elevationsMeters: const <double?>[100, 400, 400],
      climbReserveMinutesPer100m: 10,
    );
    expect(profile.totalSeconds, closeTo(4.5 * 3600, 1));
    expect(profile.secondsAtMeters(30000), closeTo(2.5 * 3600, 1));
    expect(profile.metersAtSeconds(2.5 * 3600), closeTo(30000, 1));
    final noProfile = TripStageEffortProfile.fromRoute(
      points: routePoints, routeDistanceMeters: 60000,
      averageSpeedKmh: 15,
      elevationsMeters: const <double?>[null, 400, 400],
      climbReserveMinutesPer100m: 10,
    );
    expect(noProfile.totalSeconds, closeTo(4 * 3600, 1));
  });

  test('apoio fora do corredor é rejeitado mesmo no melhor quilômetro', () {
    final distant = MapDestinationSearchResult(
      id: 'distant', title: 'Cidade distante', subtitle: '',
      latitude: 0.2, longitude: 0.2, distanceMeters: 0,
      kind: MapDestinationKind.city, source: 'offline',
    );
    final result = build(candidates: [distant]);
    expect(result.days.first.usesKnownPlace, isFalse);
    expect(result.days.first.stopKind, 'Sem local confirmado');
  });

  test('um local adequado não pode inviabilizar dias restantes', () {
    const points = <LatLng>[LatLng(0, 0), LatLng(0, 1)];
    const settings = BikeTravelPreferences(
      averageSpeedKmh: 15, ridingHoursPerDay: 4,
    );
    const late = MapDestinationSearchResult(
      id: 'late', title: 'Cidade tarde demais', subtitle: '',
      latitude: 0, longitude: 0.57, distanceMeters: 0,
      kind: MapDestinationKind.city, source: 'cache',
    );
    final plan = planner.buildPlan(
      routePoints: points, routeDistanceMeters: 120000,
      preferences: settings, destinationLabel: 'Destino',
      candidates: const [late], smartStages: true,
    );
    expect(plan.estimate.dayCount, 2);
    expect(plan.days.first.usesKnownPlace, isFalse);
    expect(plan.days.first.endDistanceMeters, closeTo(60000, 1));
    expect(plan.days.last.startDistanceMeters, plan.days.first.endDistanceMeters);
  });

  test('local próximo do alvo é selecionado sem garantir hospedagem', () {
    const suitable = MapDestinationSearchResult(
      id: 'near', title: 'Localidade junto à rota', subtitle: '',
      latitude: 0, longitude: 0.5, distanceMeters: 0,
      kind: MapDestinationKind.village, source: 'offline',
    );
    final plan = planner.buildPlan(
      routePoints: const [LatLng(0, 0), LatLng(0, 1)],
      routeDistanceMeters: 120000,
      preferences: const BikeTravelPreferences(
        averageSpeedKmh: 15, ridingHoursPerDay: 4,
      ),
      destinationLabel: 'Destino', candidates: const [suitable],
      smartStages: true,
    );
    expect(plan.days.first.usesKnownPlace, isTrue);
    expect(plan.days.first.stopLabel, 'Localidade junto à rota');
    expect(plan.days.first.routeProximityMeters!, lessThan(10));
  });

  test('campo opcional é restaurado em viagens antigas sem perda de rota', () {
    MapDestinationSearchResult city(String id, double lon) =>
        MapDestinationSearchResult(id: id, title: id, subtitle: '',
          latitude: 0, longitude: lon, distanceMeters: 0,
          kind: MapDestinationKind.city, source: 'cache');
    final trip = PlannedBikeTrip(
      id: '361', savedAt: DateTime.utc(2026, 11, 6),
      origin: city('A', 0), destination: city('B', 0.6),
      routes: const [MapCyclingRoute(
        points: routePoints, distanceMeters: 60000, durationSeconds: 14400)],
      selectedIndex: 0, averageSpeedKmh: 15,
      ridingHoursPerDay: 2, departureMinute: 420,
      breakEveryKm: 20, breakMinutes: 10, lunchMinutes: 40,
    );
    final oldJson = trip.toJson()..remove('smartStages');
    expect(PlannedBikeTrip.fromJson(oldJson).smartStages, isTrue);
    final disabled = trip.copyWith(smartStages: false);
    final restored = PlannedBikeTrip.fromJson(disabled.toJson());
    expect(restored.smartStages, isFalse);
    expect(restored.selectedRoute.distanceMeters, 60000);
    final corrupt = disabled.toJson()..['smartStages'] = 'invalid';
    expect(PlannedBikeTrip.fromJson(corrupt).smartStages, isTrue);
  });
}
