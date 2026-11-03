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
    this.ascentMeters,
    this.descentMeters,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<MapCyclingManeuver> maneuvers;
  /// Elevação calculada pelo provedor da rota, se disponibilizada.
  final double? ascentMeters;
  final double? descentMeters;
}
