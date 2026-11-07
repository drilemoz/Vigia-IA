import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Perfil cumulativo para dividir dias sem rede/GPS. O tempo adicional de
/// subida é um cenário escolhido pelo ciclista, não velocidade medida.
/// Lacunas de altitude não são interpoladas ou preenchidas artificialmente.
class TripStageEffortProfile {
  const TripStageEffortProfile._(this._meters, this._seconds);

  final List<double> _meters;
  final List<double> _seconds;

  double get totalSeconds => _seconds.last;

  factory TripStageEffortProfile.fromRoute({
    required List<LatLng> points,
    required double routeDistanceMeters,
    required double averageSpeedKmh,
    List<double?> elevationsMeters = const <double?>[],
    int climbReserveMinutesPer100m = 0,
  }) {
    final speed = averageSpeedKmh.clamp(5.0, 40.0).toDouble();
    final safeDistance = routeDistanceMeters.isFinite
        ? math.max(0.0, routeDistanceMeters).toDouble() : 0.0;
    if (points.length < 2 || safeDistance <= 0) {
      return TripStageEffortProfile._(<double>[0, safeDistance],
          <double>[0, safeDistance / (speed * 1000) * 3600]);
    }
    const geo = Distance();
    final geometry = <double>[0];
    for (var i = 1; i < points.length; i++) {
      geometry.add(geometry.last + geo.as(
          LengthUnit.Meter, points[i - 1], points[i]));
    }
    if (geometry.last <= 0 || !geometry.last.isFinite) {
      return TripStageEffortProfile._(<double>[0, safeDistance],
          <double>[0, safeDistance / (speed * 1000) * 3600]);
    }
    final scale = safeDistance / geometry.last;
    final meters = <double>[0];
    final seconds = <double>[0];
    final hasElevations = elevationsMeters.length == points.length;
    final reserve = climbReserveMinutesPer100m.clamp(0, 20).toDouble();
    for (var i = 1; i < points.length; i++) {
      final length = (geometry[i] - geometry[i - 1]) * scale;
      final a = hasElevations ? elevationsMeters[i - 1] : null;
      final b = hasElevations ? elevationsMeters[i] : null;
      final ascent = length > 0 && a != null && b != null && a.isFinite && b.isFinite
          ? math.max(0.0, b - a).toDouble() : 0.0;
      final time = length / (speed * 1000) * 3600 +
          ascent * reserve / 100 * 60;
      meters.add(geometry[i] * scale);
      seconds.add(seconds.last + time);
    }
    return TripStageEffortProfile._(meters, seconds);
  }

  double secondsAtMeters(double requestedMeters) => _interpolate(
      _meters, _seconds, requestedMeters);

  double metersAtSeconds(double requestedSeconds) => _interpolate(
      _seconds, _meters, requestedSeconds);

  // Vetores monotônicos; a busca binária evita varrer milhares de pontos
  // para cada cidade ou etapa. Segmentos degenerados têm retorno conservador.
  static double _interpolate(
      List<double> input, List<double> output, double requested) {
    if (requested <= 0 || !requested.isFinite) {
      return output.first;
    }
    if (requested >= input.last) {
      return output.last;
    }
    var low = 0;
    var high = input.length - 1;
    while (high - low > 1) {
      final middle = (low + high) ~/ 2;
      if (input[middle] < requested) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final length = input[high] - input[low];
    if (length <= 0) {
      return output[high];
    }
    final fraction = ((requested - input[low]) / length)
        .clamp(0.0, 1.0).toDouble();
    return output[low] + (output[high] - output[low]) * fraction;
  }
}
