import '../models/bike_trip_plan.dart';
import '../models/map_destination_search.dart';
import '../models/planned_bike_trip.dart';
import 'saved_bike_route_service.dart';

/// Converte a prévia já calculada no mapa para o mesmo documento utilizado
/// pelo menu Planejamento. Não dispara rede, GPS nem recálculo de geometria.
class BikeTripEditorBridge {
  const BikeTripEditorBridge._();

  static PlannedBikeTrip fromMapRoute({
    required SavedBikeRoute saved,
    required BikeTravelPreferences preferences,
    required int departureMinute,
    required int breakEveryKm,
    required int breakMinutes,
    required int lunchMinutes,
    required bool forceLunch,
    String? id,
  }) {
    if (saved.routes.isEmpty ||
        saved.selectedIndex < 0 || saved.selectedIndex >= saved.routes.length ||
        saved.routes[saved.selectedIndex].points.length < 2) {
      throw const FormatException('Prévia sem geometria para planejar');
    }
    final start = saved.routes[saved.selectedIndex].points.first;
    final target = saved.target;
    return PlannedBikeTrip(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      savedAt: DateTime.now(),
      origin: MapDestinationSearchResult(
        id: 'map-start:${start.latitude},${start.longitude}',
        title: 'Início do trajeto',
        subtitle: 'Primeiro ponto da rota calculada (não indica GPS atual)',
        latitude: start.latitude,
        longitude: start.longitude,
        distanceMeters: 0,
        kind: MapDestinationKind.place,
        source: 'map',
      ),
      destination: MapDestinationSearchResult(
        id: 'map-end:${target.latitude},${target.longitude}',
        title: target.label,
        subtitle: 'Destino selecionado no mapa',
        latitude: target.latitude,
        longitude: target.longitude,
        distanceMeters: 0,
        kind: MapDestinationKind.place,
        source: 'map',
      ),
      routes: saved.routes,
      selectedIndex: saved.selectedIndex,
      averageSpeedKmh: preferences.averageSpeedKmh.clamp(5, 40).toDouble(),
      ridingHoursPerDay: preferences.ridingHoursPerDay.clamp(1, 12).toDouble(),
      balanceDays: preferences.balanceDays,
      departureMinute: departureMinute,
      breakEveryKm: breakEveryKm,
      breakMinutes: breakMinutes,
      lunchMinutes: lunchMinutes,
      forceLunch: forceLunch,
    );
  }
}
