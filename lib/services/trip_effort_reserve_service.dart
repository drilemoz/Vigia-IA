import '../models/bike_trip_plan.dart';
import 'bike_trip_schedule.dart';
import 'trip_terrain_service.dart';

/// Simulação offline de margem de tempo declarada pelo ciclista, não uma
/// previsão física de velocidade. Somente as subidas documentadas no perfil
/// podem gerar reserva; não extrapola elevação para lacunas do provedor.
class TripEffortReserveService {
  const TripEffortReserveService._();

  static int reserveMinutes({
    required TripDayTerrain terrain,
    required int minutesPer100Meters,
  }) {
    if (!terrain.hasSamples || !terrain.ascentMeters.isFinite ||
        terrain.ascentMeters <= 0 || minutesPer100Meters <= 0) {
      return 0;
    }
    final sensitivity = minutesPer100Meters.clamp(0, 20);
    return (terrain.ascentMeters * sensitivity / 100)
        .round().clamp(0, 24 * 60).toInt();
  }

  static BikeTripDayPlan adjustedDay({
    required BikeTripDayPlan day,
    required TripDayTerrain terrain,
    required int minutesPer100Meters,
  }) {
    final extra = reserveMinutes(
      terrain: terrain, minutesPer100Meters: minutesPer100Meters,
    );
    if (extra == 0) {
      return day;
    }
    return BikeTripDayPlan(
      day: day.day,
      startDistanceMeters: day.startDistanceMeters,
      endDistanceMeters: day.endDistanceMeters,
      ridingDuration: day.ridingDuration + Duration(minutes: extra),
      stopLabel: day.stopLabel,
      stopLatitude: day.stopLatitude,
      stopLongitude: day.stopLongitude,
      stopKind: day.stopKind,
      usesKnownPlace: day.usesKnownPlace,
      routeProximityMeters: day.routeProximityMeters,
    );
  }
}

/// Alertas determinísticos sobre a viabilidade logística de cada etapa.
/// O limite de chegada é uma preferência pessoal, não o horário de pôr do sol.
class TripDayReadinessService {
  const TripDayReadinessService._();

  static List<String> notices({
    required BikeTripDayPlan day,
    required BikeTripDaySchedule schedule,
    required double targetRidingHours,
    required int latestArrivalMinute,
    required TripDayTerrain terrain,
    required int minutesPer100Meters,
  }) {
    final messages = <String>[];
    final maxSeconds = (targetRidingHours * 3600).round();
    if (maxSeconds > 0 && day.ridingDuration.inSeconds > maxSeconds) {
      messages.add('Pedalada supera o limite configurado de '
          '${targetRidingHours.toStringAsFixed(1)} h/dia. Reavalie esta etapa.');
    }
    if (schedule.arrivalMinute > latestArrivalMinute) {
      messages.add('Chegada estimada depois de '
          '${BikeTripDaySchedule.formatMinute(latestArrivalMinute)}. '
          'Não é cálculo do pôr do sol.');
    }
    if (!day.usesKnownPlace) {
      messages.add('Pernoite não confirmado: a parada é só um ponto da rota.');
    } else if (day.routeProximityMeters != null &&
        day.routeProximityMeters! > 500) {
      messages.add('Local sugerido a mais de 500 m da linha da rota; '
          'verifique o acesso real pela estrada.');
    }
    if (minutesPer100Meters > 0 && terrain.coverageFraction < 0.95) {
      messages.add(terrain.hasSamples
          ? 'Perfil incompleto: a reserva de subida só inclui trechos medidos.'
          : 'Sem perfil altimétrico: não foi possível reservar tempo por subida.');
    }
    return List<String>.unmodifiable(messages);
  }
}
