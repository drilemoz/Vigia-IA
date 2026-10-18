import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/models/planned_bike_trip.dart';
import 'package:vigiaia/services/planned_trip_export_service.dart';

void main() {
  MapDestinationSearchResult place(String label, double latitude, double longitude) =>
      MapDestinationSearchResult(
        id: label,
        title: label,
        subtitle: '',
        latitude: latitude,
        longitude: longitude,
        distanceMeters: 0,
        kind: MapDestinationKind.city,
        source: 'cache',
      );

  PlannedBikeTrip trip() => PlannedBikeTrip(
        id: 'test',
        savedAt: DateTime.utc(2026, 10, 18),
        origin: place('A & B', -20, -45),
        destination: place('Cidade <Final>', -21, -46),
        routes: const [
          MapCyclingRoute(
            points: [LatLng(-20, -45), LatLng(-21, -46)],
            distanceMeters: 150000,
            durationSeconds: 30000,
          ),
        ],
        selectedIndex: 0,
        averageSpeedKmh: 14,
        ridingHoursPerDay: 5,
        departureMinute: 420,
        breakEveryKm: 20,
        breakMinutes: 10,
        lunchMinutes: 40,
      );

  test('GPX exporta pontos reais e escapa nomes XML', () {
    final gpx = PlannedTripExportService.toGpx(trip());
    expect(gpx, contains('<gpx version="1.1"'));
    expect(gpx, contains('A &amp; B'));
    expect(gpx, contains('Cidade &lt;Final&gt;'));
    expect('<trkpt'.allMatches(gpx).length, 2);
    expect(gpx, contains('lat="-20.000000" lon="-45.000000"'));
  });

  test('JSON exportado conserva preferências e rota', () {
    final exported = jsonDecode(PlannedTripExportService.toJson(trip())) as Map<String, dynamic>;
    expect(exported['schema'], 1);
    final restored = PlannedBikeTrip.fromJson(
        Map<String, dynamic>.from(exported['trip'] as Map));
    expect(restored.averageSpeedKmh, 14);
    expect(restored.selectedRoute.points.length, 2);
  });
}
