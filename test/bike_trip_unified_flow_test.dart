import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_navigation_target.dart';
import 'package:vigiaia/models/map_travel_mode.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/services/bike_trip_editor_bridge.dart';
import 'package:vigiaia/services/bike_trip_schedule_settings_service.dart';
import 'package:vigiaia/services/saved_bike_route_service.dart';

void main() {
  final snapshot = SavedBikeRoute(
    target: MapNavigationTarget(
      latitude: -20.15,
      longitude: -44.9,
      label: 'Destino conhecido',
      startedAt: DateTime(2026, 11, 4),
      travelMode: MapTravelMode.bicycle,
    ),
    routes: const <MapCyclingRoute>[
      MapCyclingRoute(
        points: <LatLng>[LatLng(-20.55, -45.55), LatLng(-20.15, -44.9)],
        distanceMeters: 120400,
        durationSeconds: 12400,
      ),
    ],
    selectedIndex: 0,
  );

  test('mapa e menu usam o mesmo formato, sem recalcular distância', () {
    final trip = BikeTripEditorBridge.fromMapRoute(
      saved: snapshot,
      preferences: const BikeTravelPreferences(
        averageSpeedKmh: 7,
        ridingHoursPerDay: 5,
        balanceDays: false,
      ),
      departureMinute: 480,
      breakEveryKm: 15,
      breakMinutes: 20,
      lunchMinutes: 0,
      forceLunch: true,
      id: 'rota-mapa',
    );
    expect(trip.origin.title, 'Início do trajeto');
    expect(trip.selectedRoute.distanceMeters, 120400);
    expect(trip.averageSpeedKmh, 7);
    final decoded = PlannedBikeTrip.fromJson(trip.toJson());
    expect(decoded.id, 'rota-mapa');
    expect(decoded.selectedRoute.distanceMeters, 120400);
    expect(decoded.selectedRoute.points, hasLength(2));
    expect(decoded.balanceDays, isFalse);
    expect(decoded.forceLunch, isTrue);
    expect(decoded.departureMinute, 480);
    expect(decoded.breakEveryKm, 15);
    expect(decoded.breakMinutes, 20);
    expect(decoded.lunchMinutes, 0);
  });

  test('viagens antigas sem novos campos continuam legíveis', () {
    final trip = BikeTripEditorBridge.fromMapRoute(
      saved: snapshot,
      preferences: const BikeTravelPreferences(),
      departureMinute: 420,
      breakEveryKm: 20,
      breakMinutes: 10,
      lunchMinutes: 40,
      forceLunch: false,
    );
    final legacy = trip.toJson()
      ..remove('balanceDays')
      ..remove('forceLunch');
    final decoded = PlannedBikeTrip.fromJson(legacy);
    expect(decoded.balanceDays, isTrue);
    expect(decoded.forceLunch, isFalse);
  });

  test('preferências persistidas validam horário, pausas e almoço', () {
    final settings = BikeTripScheduleSettings.fromJson({
      'schema': 1,
      'departureMinute': 2000,
      'breakEveryKm': 2,
      'breakMinutes': 500,
      'lunchMinutes': -1,
      'forceLunch': true,
    });
    expect(settings.departureMinute, 1439);
    expect(settings.breakEveryKm, 5);
    expect(settings.breakMinutes, 60);
    expect(settings.lunchMinutes, 0);
    expect(settings.forceLunch, isTrue);
    expect(() => BikeTripScheduleSettings.fromJson({'schema': 2}),
      throwsFormatException);
  });
}
