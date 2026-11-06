import 'package:latlong2/latlong.dart';

import 'map_cycling_route.dart';
import 'map_destination_search.dart';
import 'map_navigation_target.dart';
import 'map_travel_mode.dart';
import 'trip_weather_day_forecast.dart';
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
    this.balanceDays = true,
    this.forceLunch = false,
    this.climbReserveMinutesPer100m = 0,
    this.latestArrivalMinute = 18 * 60,
    this.places = const <MapDestinationSearchResult>[],
    this.startDate,
    this.weatherDays = const <TripWeatherDayForecast>[],
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
  final bool balanceDays;
  final bool forceLunch;
  /// Tempo extra escolhido pelo usuário a cada 100 m de subida documentada.
  /// Zero mantém a estimativa anterior, sem alteração de velocidade.
  final int climbReserveMinutesPer100m;
  /// Limite pessoal para chegada. Não representa anoitecer astronômico.
  final int latestArrivalMinute;
  final List<MapDestinationSearchResult> places;
  /// Data local escolhida pelo usuário, sem assumir hoje automaticamente.
  final DateTime? startDate;
  /// Última previsão obtida manualmente, legível offline com data/hora.
  final List<TripWeatherDayForecast> weatherDays;

  MapCyclingRoute get selectedRoute => routes[selectedIndex];

  PlannedBikeTrip copyWith({
    int? selectedIndex,
    List<MapDestinationSearchResult>? places,
    DateTime? startDate,
    bool clearStartDate = false,
    List<TripWeatherDayForecast>? weatherDays,
    double? averageSpeedKmh,
    double? ridingHoursPerDay,
    int? departureMinute,
    int? breakEveryKm,
    int? breakMinutes,
    int? lunchMinutes,
    bool? balanceDays,
    bool? forceLunch,
    int? climbReserveMinutesPer100m,
    int? latestArrivalMinute,
  }) => PlannedBikeTrip(
    id: id, savedAt: savedAt, origin: origin, destination: destination,
    routes: routes, selectedIndex: selectedIndex ?? this.selectedIndex,
    averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
    ridingHoursPerDay: ridingHoursPerDay ?? this.ridingHoursPerDay,
    departureMinute: departureMinute ?? this.departureMinute,
    breakEveryKm: breakEveryKm ?? this.breakEveryKm,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    lunchMinutes: lunchMinutes ?? this.lunchMinutes,
    balanceDays: balanceDays ?? this.balanceDays,
    forceLunch: forceLunch ?? this.forceLunch,
    climbReserveMinutesPer100m: climbReserveMinutesPer100m ?? this.climbReserveMinutesPer100m,
    latestArrivalMinute: latestArrivalMinute ?? this.latestArrivalMinute,
    places: places ?? this.places,
    startDate: clearStartDate ? null : startDate ?? this.startDate,
    weatherDays: weatherDays ?? this.weatherDays,
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
    'balanceDays': balanceDays,
    'forceLunch': forceLunch,
    'climbReserveMinutesPer100m': climbReserveMinutesPer100m,
    'latestArrivalMinute': latestArrivalMinute,
    'places': [for (final place in places.take(100)) place.toJson()],
    'startDate': startDate?.toIso8601String(),
    'weatherDays': [for (final forecast in weatherDays.take(16)) forecast.toJson()],
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
    // Cache opcional: uma amostra corrompida não bloqueia a viagem salva.
    final forecastDays = <TripWeatherDayForecast>[];
    final rawWeather = json['weatherDays'];
    if (rawWeather is List) {
      for (final item in rawWeather.take(16)) {
        if (item is! Map) {
          continue;
        }
        try {
          forecastDays.add(TripWeatherDayForecast.fromJson(
            Map<String, dynamic>.from(item)));
        } catch (_) {
          // Descarta só o registro meteorológico inválido.
        }
      }
    }
    final parsedDate = json['startDate'] is String
        ? DateTime.tryParse(json['startDate'] as String) : null;
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
      balanceDays: json['balanceDays'] is bool ? json['balanceDays'] as bool : true,
      forceLunch: json['forceLunch'] == true,
      climbReserveMinutesPer100m:
          (json['climbReserveMinutesPer100m'] is num &&
                  (json['climbReserveMinutesPer100m'] as num).isFinite
              ? (json['climbReserveMinutesPer100m'] as num).toInt() : 0)
              .clamp(0, 20).toInt(),
      latestArrivalMinute: ((json['latestArrivalMinute'] is num &&
                  (json['latestArrivalMinute'] as num).isFinite
              ? (json['latestArrivalMinute'] as num).toInt() : 18 * 60) / 60)
              .round().clamp(15, 21).toInt() * 60,
      places: List<MapDestinationSearchResult>.unmodifiable(places),
      startDate: parsedDate,
      weatherDays: List<TripWeatherDayForecast>.unmodifiable(forecastDays),
    );
  }
}

/// Resultado do editor ao regressar para a mesma instância de Mapas.
/// Um foco opcional indica a parada que o usuário decidiu inspecionar.
class BikeTripEditorResult {
  const BikeTripEditorResult({required this.trip, this.focusPoint});

  final PlannedBikeTrip trip;
  final LatLng? focusPoint;
}
