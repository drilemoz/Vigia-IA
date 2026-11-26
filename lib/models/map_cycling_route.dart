import 'package:latlong2/latlong.dart';

class MapCyclingManeuver {
  const MapCyclingManeuver({
    required this.instruction,
    required this.beginShapeIndex,
    required this.endShapeIndex,
    required this.distanceMeters,
    required this.durationSeconds,
    this.type,
    this.streetName,
  });

  final String instruction;
  final int beginShapeIndex;
  final int endShapeIndex;
  final double distanceMeters;
  final double durationSeconds;
  final int? type;
  final String? streetName;
}

class MapCyclingRoute {
  const MapCyclingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.maneuvers = const <MapCyclingManeuver>[],
    this.pavedMeters = 0,
    this.unpavedMeters = 0,
    this.ascentMeters,
    this.descentMeters,
    this.elevationsMeters = const <double?>[],
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<MapCyclingManeuver> maneuvers;
  /// Distâncias de pavimento informadas pelo provedor; desconhecido é separado.
  final double pavedMeters;
  final double unpavedMeters;
  double get unknownSurfaceMeters => (distanceMeters - pavedMeters - unpavedMeters).clamp(0.0, distanceMeters).toDouble();
  String get surfaceLabel => 'Pavimentado ${(pavedMeters / 1000).toStringAsFixed(1)} km · '
      'Não pavimentado ${(unpavedMeters / 1000).toStringAsFixed(1)} km · '
      'Desconhecido ${(unknownSurfaceMeters / 1000).toStringAsFixed(1)} km';
  /// Elevação calculada pelo provedor da rota, se disponibilizada.
  final double? ascentMeters;
  final double? descentMeters;
  /// Altitudes em metros, alinhadas aos vértices. Vazio: provedor sem perfil.
  /// Um valor null representa amostra ausente, nunca altitude zero inventada.
  final List<double?> elevationsMeters;
}
