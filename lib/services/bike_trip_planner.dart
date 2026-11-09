import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_destination_search.dart';
import 'trip_stage_effort_profile.dart';

class BikeTripPlanner {
  const BikeTripPlanner();

  BikeTripEstimate estimate({
    required double distanceMeters,
    required BikeTravelPreferences preferences,
  }) {
    final safeDistance = math.max(0.0, distanceMeters).toDouble();
    final safeSpeed = preferences.averageSpeedKmh.clamp(5.0, 40.0).toDouble();
    final safeHours = preferences.ridingHoursPerDay.clamp(1.0, 12.0).toDouble();
    final ridingHours = safeDistance / 1000 / safeSpeed;
    final seconds = (ridingHours * 3600).round();
    final days = ridingHours <= 0
        ? 1
        : math.max(1, (ridingHours / safeHours).ceil()).toInt();
    return BikeTripEstimate(
      distanceMeters: safeDistance,
      ridingDuration: Duration(seconds: seconds),
      dayCount: days,
      preferences: preferences.copyWith(
        averageSpeedKmh: safeSpeed,
        ridingHoursPerDay: safeHours,
      ),
    );
  }

  Duration remainingDuration({
    required double remainingDistanceMeters,
    required BikeTravelPreferences preferences,
  }) {
    return estimate(
      distanceMeters: remainingDistanceMeters,
      preferences: preferences,
    ).ridingDuration;
  }

  BikeTripPlan buildPlan({
    required List<LatLng> routePoints,
    required double routeDistanceMeters,
    required BikeTravelPreferences preferences,
    required String destinationLabel,
    required List<MapDestinationSearchResult> candidates,
    List<double?> elevationsMeters = const <double?>[],
    int climbReserveMinutesPer100m = 0,
    bool smartStages = false,
    double? dailyDistanceTargetKm,
    bool distanceGoalFirstDayOnly = true,
  }) {
    final tripEstimate = estimate(
      distanceMeters: routeDistanceMeters,
      preferences: preferences,
    );
    if (routePoints.length < 2) {
      return BikeTripPlan(estimate: tripEstimate, days: const <BikeTripDayPlan>[]);
    }

    final cumulative = <double>[0];
    var geometryMeters = 0.0;
    const distance = Distance();
    for (var index = 1; index < routePoints.length; index++) {
      geometryMeters += distance.as(
        LengthUnit.Meter,
        routePoints[index - 1],
        routePoints[index],
      );
      cumulative.add(geometryMeters);
    }
    final scale = geometryMeters <= 0 ? 1.0 : routeDistanceMeters / geometryMeters;
    final mappedCandidates = _mapCandidatesToRoute(
      routePoints: routePoints,
      cumulativeGeometryMeters: cumulative,
      geometryScale: scale,
      candidates: candidates,
    );

    final effort = smartStages ? TripStageEffortProfile.fromRoute(
      points: routePoints,
      routeDistanceMeters: routeDistanceMeters,
      averageSpeedKmh: tripEstimate.preferences.averageSpeedKmh,
      elevationsMeters: elevationsMeters,
      climbReserveMinutesPer100m: climbReserveMinutesPer100m,
    ) : null;
    // Sem perfil, o esforço é só tempo de pedal em velocidade fixa.
    // A divisão inteligente não transforma ausência de altitude em subida.
    final daySeconds = tripEstimate.preferences.ridingHoursPerDay * 3600;
    // Meta opcional: preferências de horas continuam válidas para viagens antigas.
    final distanceGoalMeters = dailyDistanceTargetKm != null &&
        dailyDistanceTargetKm.isFinite &&
        dailyDistanceTargetKm >= 5 && dailyDistanceTargetKm <= 300
        ? dailyDistanceTargetKm * 1000 : null;
    final firstGoalMeters = math.min(routeDistanceMeters,
        distanceGoalMeters ?? routeDistanceMeters).toDouble();
    final totalEffortSeconds = effort?.totalSeconds ??
        tripEstimate.ridingDuration.inSeconds.toDouble();
    final firstGoalEffortSeconds = effort?.secondsAtMeters(firstGoalMeters) ??
        firstGoalMeters / 1000 / tripEstimate.preferences.averageSpeedKmh * 3600;
    final int dayCount;
    if (distanceGoalMeters == null) {
      dayCount = effort == null ? tripEstimate.dayCount :
          math.max(1, (effort.totalSeconds / daySeconds).ceil()).toInt();
    } else if (distanceGoalFirstDayOnly && firstGoalMeters < routeDistanceMeters) {
      final remainingSeconds = math.max(0.0,
          totalEffortSeconds - firstGoalEffortSeconds).toDouble();
      dayCount = 1 + math.max(1, (remainingSeconds / daySeconds).ceil()).toInt();
    } else {
      dayCount = math.max(1, (routeDistanceMeters / distanceGoalMeters).ceil()).toInt();
    }
    final planEstimate = BikeTripEstimate(
      distanceMeters: tripEstimate.distanceMeters,
      ridingDuration: tripEstimate.ridingDuration,
      dayCount: dayCount,
      preferences: tripEstimate.preferences,
    );
    final days = <BikeTripDayPlan>[];
    final usedIds = <String>{};
    // Sempre reserva espaço para as etapas restantes, mesmo quando uma
    // localidade próxima da meta fica adiante do fim nominal do dia.
    // Isto impede etapas com distância negativa ou final anterior ao início.
    final minimumAdvance = routeDistanceMeters > 0
        ? math.min(500.0, routeDistanceMeters / (dayCount * 2)).toDouble()
        : 0.0;
    var previousEnd = 0.0;
    for (var day = 1; day <= dayCount; day++) {
      final finalDay = day == dayCount;
      final previousEffort = effort?.secondsAtMeters(previousEnd) ?? 0.0;
      final remainingDays = dayCount - day + 1;
      final usingDistanceToday = distanceGoalMeters != null &&
          (!distanceGoalFirstDayOnly || day == 1);
      // Primeiro dia por quilômetros: o restante volta à duração diária;
      // todos os dias por quilômetros: aproxima a meta sem fabricar apoios.
      final double idealEnd;
      if (finalDay) {
        idealEnd = routeDistanceMeters;
      } else if (usingDistanceToday) {
        idealEnd = distanceGoalFirstDayOnly
            ? firstGoalMeters
            : tripEstimate.preferences.balanceDays
                ? routeDistanceMeters * day / dayCount
                : math.min(routeDistanceMeters, distanceGoalMeters! * day).toDouble();
      } else if (distanceGoalMeters != null && distanceGoalFirstDayOnly) {
        if (effort == null) {
          final remainingDistance = routeDistanceMeters - firstGoalMeters;
          idealEnd = tripEstimate.preferences.balanceDays
              ? firstGoalMeters + remainingDistance * (day - 1) / (dayCount - 1)
              : math.min(routeDistanceMeters, firstGoalMeters +
                  (day - 1) * tripEstimate.preferences.averageSpeedKmh *
                  tripEstimate.preferences.ridingHoursPerDay * 1000).toDouble();
        } else {
          final targetEffort = tripEstimate.preferences.balanceDays
              ? previousEffort + (effort.totalSeconds - previousEffort) / remainingDays
              : math.min(effort.totalSeconds, previousEffort + daySeconds).toDouble();
          idealEnd = effort.metersAtSeconds(targetEffort);
        }
      } else if (effort == null) {
        idealEnd = _idealCumulativeDistance(
            day: day, totalDays: dayCount, totalDistanceMeters: routeDistanceMeters,
            preferences: tripEstimate.preferences);
      } else {
        final idealEffort = tripEstimate.preferences.balanceDays
            ? previousEffort + (effort.totalSeconds - previousEffort) / remainingDays
            : math.min(effort.totalSeconds, previousEffort + daySeconds).toDouble();
        idealEnd = effort.metersAtSeconds(idealEffort);
      }
      final minEnd = math.min(routeDistanceMeters,
          previousEnd + minimumAdvance).toDouble();
      var maxEnd = routeDistanceMeters - minimumAdvance * (remainingDays - 1);
      // Uma parada sugerida não pode engolir o trecho do dia seguinte.
      if (distanceGoalMeters != null && !distanceGoalFirstDayOnly &&
          day < dayCount - 1) {
        final nextGoalEnd = tripEstimate.preferences.balanceDays
            ? routeDistanceMeters * (day + 1) / dayCount
            : math.min(routeDistanceMeters, distanceGoalMeters * (day + 1));
        maxEnd = math.min(maxEnd, nextGoalEnd - minimumAdvance).toDouble();
      }
      maxEnd = math.max(minEnd, maxEnd).toDouble();
      final boundedIdealEnd = finalDay ? routeDistanceMeters :
          idealEnd.clamp(minEnd, maxEnd).toDouble();
      final idealSeconds = effort?.secondsAtMeters(boundedIdealEnd) ?? 0.0;
      _MappedTripCandidate? selected;
      if (!finalDay) {
        final dailyTarget = boundedIdealEnd - previousEnd;
        final maxDelta = usingDistanceToday
            ? math.max(1000.0, dailyTarget * 0.35).toDouble()
            : math.max(18000.0, dailyTarget * 0.35).toDouble();
        for (final candidate in mappedCandidates) {
          if (usedIds.contains(candidate.result.id)) {
            continue;
          }
          if (candidate.routeDistanceMeters <=
              math.max(previousEnd + minimumAdvance, previousEnd + 500.0) ||
              candidate.routeDistanceMeters > maxEnd) {
            continue;
          }
          if (candidate.routeDistanceMeters >= routeDistanceMeters - 5000) {
            continue;
          }
          // Proximidade em linha reta NÃO assegura acesso pela estrada.
          if (candidate.routeProximityMeters > 1500) {
            continue;
          }
          // No modo por quilômetros, uma sugestão de local não autoriza
          // ultrapassar o teto de pedal, nem deixar esforço impossível
          // para as etapas restantes. O acesso ao local ainda é manual.
          if (distanceGoalMeters != null) {
            final candidateEffort = effort?.secondsAtMeters(
                candidate.routeDistanceMeters) ??
                candidate.routeDistanceMeters / 1000 /
                    tripEstimate.preferences.averageSpeedKmh * 3600;
            final previousTotalEffort = effort?.secondsAtMeters(previousEnd) ??
                previousEnd / 1000 /
                    tripEstimate.preferences.averageSpeedKmh * 3600;
            if (candidateEffort - previousTotalEffort > daySeconds * 1.001 ||
                totalEffortSeconds - candidateEffort >
                    (dayCount - day) * daySeconds * 1.001) {
              continue;
            }
          }
          final delta = (candidate.routeDistanceMeters - boundedIdealEnd).abs();
          if (effort == null || usingDistanceToday) {
            if (delta > maxDelta) {
              continue;
            }
          } else {
            final candidateEffort = effort.secondsAtMeters(
                candidate.routeDistanceMeters);
            final segmentEffort = candidateEffort - previousEffort;
            // Evita escolher cidade que ultrapasse o próprio orçamento
            // diário ou inviabilize os dias restantes.
            if (segmentEffort > daySeconds * 1.001 ||
                segmentEffort < daySeconds * 0.55 ||
                effort.totalSeconds - candidateEffort >
                    (dayCount - day) * daySeconds * 1.001) {
              continue;
            }
            if ((candidateEffort - idealSeconds).abs() >
                daySeconds * 0.40) {
              continue;
            }
          }
          final score = effort == null || usingDistanceToday ? delta +
              candidate.routeProximityMeters * 2.2 +
              _kindPenalty(candidate.result.kind) :
              (effort.secondsAtMeters(candidate.routeDistanceMeters) -
                  idealSeconds).abs() +
                  (candidate.routeProximityMeters * 2.2 +
                      _kindPenalty(candidate.result.kind)) /
                      (tripEstimate.preferences.averageSpeedKmh * 1000) * 3600;
          if (selected == null || score < selected.score) {
            selected = candidate.copyWith(score: score);
          }
        }
      }

      final endDistance = finalDay ? routeDistanceMeters :
          (selected?.routeDistanceMeters ?? boundedIdealEnd)
              .clamp(minEnd, maxEnd).toDouble();
      final routePoint = _pointAtDistance(
        routePoints: routePoints,
        cumulativeGeometryMeters: cumulative,
        geometryScale: scale,
        targetMeters: endDistance,
      );
      if (selected != null) usedIds.add(selected.result.id);
      final segmentMeters = math.max(0.0, endDistance - previousEnd).toDouble();
      final seconds = (segmentMeters /
              1000 /
              tripEstimate.preferences.averageSpeedKmh *
              3600)
          .round();
      days.add(
        BikeTripDayPlan(
          day: day,
          startDistanceMeters: previousEnd,
          endDistanceMeters: endDistance,
          ridingDuration: Duration(seconds: seconds),
          stopLabel: finalDay
              ? destinationLabel
              : selected?.result.title ?? 'Parada aproximada na rota',
          stopLatitude: selected?.result.latitude ?? routePoint.latitude,
          stopLongitude: selected?.result.longitude ?? routePoint.longitude,
          stopKind: finalDay
              ? 'Destino'
              : selected == null
                  ? 'Sem local confirmado'
                  : selected.result.kind.label,
          usesKnownPlace: finalDay || selected != null,
          routeProximityMeters: selected?.routeProximityMeters,
        ),
      );
      previousEnd = endDistance;
    }
    return BikeTripPlan(
      estimate: planEstimate,
      days: List<BikeTripDayPlan>.unmodifiable(days),
    );
  }

  double _idealCumulativeDistance({
    required int day,
    required int totalDays,
    required double totalDistanceMeters,
    required BikeTravelPreferences preferences,
  }) {
    if (preferences.balanceDays) {
      return totalDistanceMeters * day / totalDays;
    }
    final dailyMeters = preferences.averageSpeedKmh *
        preferences.ridingHoursPerDay *
        1000;
    return math.min(totalDistanceMeters, dailyMeters * day).toDouble();
  }

  List<_MappedTripCandidate> _mapCandidatesToRoute({
    required List<LatLng> routePoints,
    required List<double> cumulativeGeometryMeters,
    required double geometryScale,
    required List<MapDestinationSearchResult> candidates,
  }) {
    const distance = Distance();
    // A projeção por trecho evita confundir um ponto no meio de uma via
    // com outro a muitos quilômetros de um vértice. Amostragem limitada
    // mantém custo previsível em geometria extensa (até ~450 trechos).
    final step = math.max(1, (routePoints.length / 450).ceil()).toInt();
    final mapped = <_MappedTripCandidate>[];
    for (final result in candidates) {
      final candidatePoint = LatLng(result.latitude, result.longitude);
      var nearestMeters = double.infinity;
      var nearestGeometryMeters = 0.0;
      for (var index = 0; index < routePoints.length - 1; index += step) {
        final next = math.min(index + step, routePoints.length - 1).toInt();
        final a = routePoints[index];
        final b = routePoints[next];
        // Plano local equiretangular: somente para localizar o ponto mais
        // próximo no segmento. A distância exibida usa geodesia (Distance).
        final cosLat = math.cos(candidatePoint.latitude * math.pi / 180);
        final dx = (b.longitude - a.longitude) * cosLat;
        final dy = b.latitude - a.latitude;
        final px = (candidatePoint.longitude - a.longitude) * cosLat;
        final py = candidatePoint.latitude - a.latitude;
        final squared = dx * dx + dy * dy;
        final t = squared < 1e-20
            ? 0.0 : ((px * dx + py * dy) / squared).clamp(0.0, 1.0).toDouble();
        final point = LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        final meters = distance.as(LengthUnit.Meter, candidatePoint, point);
        if (meters < nearestMeters) {
          nearestMeters = meters;
          nearestGeometryMeters = cumulativeGeometryMeters[index] +
              (cumulativeGeometryMeters[next] - cumulativeGeometryMeters[index]) * t;
        }
      }
      mapped.add(_MappedTripCandidate(
        result: result,
        routeDistanceMeters: nearestGeometryMeters * geometryScale,
        routeProximityMeters: nearestMeters,
        score: double.infinity,
      ));
    }
    return mapped;
  }

  LatLng _pointAtDistance({
    required List<LatLng> routePoints,
    required List<double> cumulativeGeometryMeters,
    required double geometryScale,
    required double targetMeters,
  }) {
    for (var index = 1; index < cumulativeGeometryMeters.length; index++) {
      final endMeters = cumulativeGeometryMeters[index] * geometryScale;
      if (endMeters >= targetMeters) {
        final startMeters = cumulativeGeometryMeters[index - 1] * geometryScale;
        final interval = endMeters - startMeters;
        final fraction = interval <= 0 ? 0.0 :
            ((targetMeters - startMeters) / interval).clamp(0.0, 1.0).toDouble();
        final a = routePoints[index - 1];
        final b = routePoints[index];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * fraction,
          a.longitude + (b.longitude - a.longitude) * fraction,
        );
      }
    }
    return routePoints.last;
  }

  double _kindPenalty(MapDestinationKind kind) => switch (kind) {
        MapDestinationKind.city => 0.0,
        MapDestinationKind.town => 1000.0,
        MapDestinationKind.village => 2500.0,
        MapDestinationKind.community => 4500.0,
        MapDestinationKind.pointOfInterest => 3500.0,
        MapDestinationKind.place => 7000.0,
      };
}

class _MappedTripCandidate {
  const _MappedTripCandidate({
    required this.result,
    required this.routeDistanceMeters,
    required this.routeProximityMeters,
    required this.score,
  });

  final MapDestinationSearchResult result;
  final double routeDistanceMeters;
  final double routeProximityMeters;
  final double score;

  _MappedTripCandidate copyWith({double? score}) => _MappedTripCandidate(
        result: result,
        routeDistanceMeters: routeDistanceMeters,
        routeProximityMeters: routeProximityMeters,
        score: score ?? this.score,
      );
}
