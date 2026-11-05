import 'map_cycling_route.dart';
import 'map_destination_search.dart';
import 'map_navigation_target.dart';
import 'map_travel_mode.dart';
import '../services/saved_bike_route_service.dart';

/// Viagem preparada, sem vincular a origem ao GPS nem iniciar navegação.
/// A geometria é persistida para consulta offline; não é grafo de roteamento.
class PlannedBikeTrip {
  const PlannedBikeTrip({
    required this.id,
    required this.savedAt,
    required this.origin,
    required this.destination,
    required this.routes,
    required this.selectedIndex,
    required this.averageSpeedKmh,
    required this.ridingHoursPerDay,
    required this.departureMinute,
    required this.breakEveryKm,
    required this.breakMinutes,
    required this.lunchMinutes,
    this.places = const <MapDestinationSearchResult>[],
  });

  final String id;
  final DateTime savedAt;
  final MapDestinationSearchResult origin;
  final MapDestinationSearchResult destination;
  final List<MapCyclingRoute> routes;
  final int selectedIndex;
  final double averageSpeedKmh;
  final double ridingHoursPerDay;
  final int departureMinute;
  final int breakEveryKm;
  final int breakMinutes;
  final int lunchMinutes;
  final List<MapDestinationSearchResult> places;

  MapCyclingRoute get selectedRoute => routes[selectedIndex];

  PlannedBikeTrip copyWith({
    int? selectedIndex,
    List<MapDestinationSearchResult>? places,
    double? averageSpeedKmh,
    double? ridingHoursPerDay,
    int? departureMinute,
    int? breakEveryKm,
    int? breakMinutes,
    int? lunchMinutes,
  }) => PlannedBikeTrip(
    id: id, savedAt: savedAt, origin: origin, destination: destination,
    routes: routes, selectedIndex: selectedIndex ?? this.selectedIndex,
    averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
    ridingHoursPerDay: ridingHoursPerDay ?? this.ridingHoursPerDay,
    departureMinute: departureMinute ?? this.departureMinute,
    breakEveryKm: breakEveryKm ?? this.breakEveryKm,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    lunchMinutes: lunchMinutes ?? this.lunchMinutes,
    places: places ?? this.places,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    'route': SavedBikeRouteService.encode(SavedBikeRoute(
      target: MapNavigationTarget(
        latitude: destination.latitude,
        longitude: destination.longitude,
        label: destination.title,
        startedAt: savedAt,
        travelMode: MapTravelMode.bicycle,
      ),
      routes: routes,
      selectedIndex: selectedIndex,
    )),
    'speed': averageSpeedKmh,
    'hours': ridingHoursPerDay,
    'departureMinute': departureMinute,
    'breakEveryKm': breakEveryKm,
    'breakMinutes': breakMinutes,
    'lunchMinutes': lunchMinutes,
    'places': [for (final place in places.take(100)) place.toJson()],
  };

  factory PlannedBikeTrip.fromJson(Map<String, dynamic> json) {
    final savedRoute = SavedBikeRouteService.decode(json['route']);
    final speed = (json['speed'] as num?)?.toDouble() ?? 15;
    final hours = (json['hours'] as num?)?.toDouble() ?? 5;
    if (!speed.isFinite || speed < 5 || speed > 40 ||
        !hours.isFinite || hours < 1 || hours > 12) {
      throw const FormatException('Preferências inválidas');
    }
    final places = <MapDestinationSearchResult>[];
    for (final item in (json['places'] as List? ?? const []).take(100)) {
      if (item is Map) {
        places.add(MapDestinationSearchResult.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    final origin = MapDestinationSearchResult.fromJson(
      Map<String, dynamic>.from(json['origin'] as Map));
    final destination = MapDestinationSearchResult.fromJson(
      Map<String, dynamic>.from(json['destination'] as Map));
    if (!origin.latitude.isFinite || !origin.longitude.isFinite ||
        !destination.latitude.isFinite || !destination.longitude.isFinite ||
        origin.latitude.abs() > 90 || origin.longitude.abs() > 180 ||
        destination.latitude.abs() > 90 || destination.longitude.abs() > 180) {
      throw const FormatException('Cidade com coordenadas inválidas');
    }
    return PlannedBikeTrip(
      id: json['id'] as String? ?? '',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      origin: origin, destination: destination,
      routes: List<MapCyclingRoute>.unmodifiable(savedRoute.routes),
      selectedIndex: savedRoute.selectedIndex,
      averageSpeedKmh: speed, ridingHoursPerDay: hours,
      departureMinute: ((json['departureMinute'] as num?)?.toInt() ?? 420).clamp(0, 1439).toInt(),
      breakEveryKm: ((json['breakEveryKm'] as num?)?.toInt() ?? 20).clamp(5, 100).toInt(),
      breakMinutes: ((json['breakMinutes'] as num?)?.toInt() ?? 10).clamp(0, 60).toInt(),
      lunchMinutes: ((json['lunchMinutes'] as num?)?.toInt() ?? 40).clamp(0, 120).toInt(),
      places: List<MapDestinationSearchResult>.unmodifiable(places),
    );
  }
}
