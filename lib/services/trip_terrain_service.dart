import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_cycling_route.dart';

/// Divide o desnível de amostras reais pelos limites das etapas do roteiro.
/// Não atribui inclinação a rotas que só têm o resumo agregado do provedor.
class TripDayTerrain {
  const TripDayTerrain({
    required this.ascentMeters,
    required this.descentMeters,
    required this.coveredMeters,
    required this.dayMeters,
  });
  final double ascentMeters;
  final double descentMeters;
  final double coveredMeters;
  final double dayMeters;

  bool get hasSamples => coveredMeters > 0;
  double get coverageFraction => dayMeters <= 0
      ? 0 : (coveredMeters / dayMeters).clamp(0.0, 1.0).toDouble();
}

class TripTerrainService {
  const TripTerrainService._();

  static List<TripDayTerrain> forDays({
    required MapCyclingRoute route,
    required List<BikeTripDayPlan> days,
  }) {
    final ups = List<double>.filled(days.length, 0);
    final downs = List<double>.filled(days.length, 0);
    final covered = List<double>.filled(days.length, 0);
    final heights = route.elevationsMeters;
    if (heights.length != route.points.length ||
        route.points.length < 2 || route.distanceMeters <= 0 || days.isEmpty) {
      return [
        for (final day in days)
          TripDayTerrain(ascentMeters: 0, descentMeters: 0,
              coveredMeters: 0, dayMeters: day.distanceMeters),
      ];
    }
    const geo = Distance();
    final meters = <double>[0];
    var totalGeometry = 0.0;
    for (var i = 1; i < route.points.length; i++) {
      totalGeometry += geo.as(LengthUnit.Meter, route.points[i - 1], route.points[i]);
      meters.add(totalGeometry);
    }
    if (totalGeometry <= 0) {
      return [
        for (final day in days)
          TripDayTerrain(ascentMeters: 0, descentMeters: 0,
              coveredMeters: 0, dayMeters: day.distanceMeters),
      ];
    }
    final scale = route.distanceMeters / totalGeometry;
    var firstDay = 0;
    for (var i = 1; i < route.points.length; i++) {
      final h0 = heights[i - 1];
      final h1 = heights[i];
      if (h0 == null || h1 == null) {
        continue;
      }
      final start = meters[i - 1] * scale;
      final end = meters[i] * scale;
      final length = end - start;
      if (length <= 0) {
        continue;
      }
      while (firstDay < days.length && days[firstDay].endDistanceMeters <= start) {
        firstDay++;
      }
      if (firstDay >= days.length) {
        break;
      }
      final delta = h1 - h0;
      for (var d = firstDay; d < days.length; d++) {
        final day = days[d];
        if (day.startDistanceMeters >= end) {
          break;
        }
        final overlap = math.min(end, day.endDistanceMeters) -
            math.max(start, day.startDistanceMeters);
        if (overlap <= 0) {
          continue;
        }
        final share = overlap / length;
        covered[d] += overlap;
        if (delta >= 0) {
          ups[d] += delta * share;
        } else {
          downs[d] += -delta * share;
        }
      }
    }
    return [
      for (var d = 0; d < days.length; d++)
        TripDayTerrain(ascentMeters: ups[d], descentMeters: downs[d],
            coveredMeters: covered[d], dayMeters: days[d].distanceMeters),
    ];
  }
}
