import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/services/bike_trip_planner.dart';
import 'package:vigiaia/services/bike_trip_schedule.dart';

void main() {
  MapDestinationSearchResult city(String id, double lat, double lon) =>
      MapDestinationSearchResult(
        id: id, title: id, subtitle: 'MG, Brasil',
        latitude: lat, longitude: lon, distanceMeters: 0,
        kind: MapDestinationKind.city, source: 'cache',
      );

  PlannedBikeTrip trip() => PlannedBikeTrip(
        id: 'trip-1',
        savedAt: DateTime.utc(2026, 10, 18),
        origin: city('Origem', -20, -45),
        destination: city('Destino', -21, -46),
        routes: [
          MapCyclingRoute(
            points: const [LatLng(-20, -45), LatLng(-21, -46)],
            distanceMeters: 300000,
            durationSeconds: 60000,
          ),
        ],
        selectedIndex: 0,
        averageSpeedKmh: 15,
        ridingHoursPerDay: 5,
        departureMinute: 420,
        breakEveryKm: 20,
        breakMinutes: 10,
        lunchMinutes: 40,
      );

  test('Viagem persiste origem, destino, geometrias e preferências', () {
    final original = trip();
    final restored = PlannedBikeTrip.fromJson(original.toJson());
    expect(restored.id, 'trip-1');
    expect(restored.origin.title, 'Origem');
    expect(restored.destination.longitude, -46);
    expect(restored.selectedRoute.points.length, 2);
    expect(restored.selectedRoute.distanceMeters, 300000);
    expect(restored.departureMinute, 420);
    expect(restored.breakEveryKm, 20);
  });

  test('Estimativa de dias depende da velocidade, não da duração Valhalla', () {
    final result = const BikeTripPlanner().estimate(
      distanceMeters: trip().selectedRoute.distanceMeters,
      preferences: const BikeTravelPreferences(
        averageSpeedKmh: 15, ridingHoursPerDay: 5,
      ),
    );
    expect(result.ridingHours, 20);
    expect(result.dayCount, 4);
  });

  test('Roteiro gera paradas aproximadas sem inventar cidades', () {
    final t = trip();
    final plan = const BikeTripPlanner().buildPlan(
      routePoints: t.selectedRoute.points,
      routeDistanceMeters: t.selectedRoute.distanceMeters,
      preferences: const BikeTravelPreferences(
        averageSpeedKmh: 15, ridingHoursPerDay: 5,
      ),
      destinationLabel: t.destination.title,
      candidates: const [],
    );
    expect(plan.days.length, 4);
    expect(plan.days.first.usesKnownPlace, isFalse);
    expect(plan.days.last.stopLabel, 'Destino');
    final schedule = BikeTripSchedule.forDay(day: plan.days.first);
    expect(schedule.breakCount, greaterThan(0));
    expect(schedule.arrivalMinute, greaterThan(schedule.departureMinute));
  });

  test('Valida preferências impossíveis ao carregar', () {
    final json = trip().toJson();
    json['speed'] = 0;
    expect(() => PlannedBikeTrip.fromJson(json), throwsFormatException);
  });
}
