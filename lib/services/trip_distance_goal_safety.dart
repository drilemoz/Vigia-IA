import '../models/bike_trip_plan.dart';
import 'bike_trip_schedule.dart';

/// Valida a meta de distância antes da busca de rota. São estimativas de base;
/// as reservas de subida, vento e acesso real continuam sendo verificadas na
/// prévia, quando há geometria e altitude disponíveis.
class TripDistanceGoalSafety {
  const TripDistanceGoalSafety._();

  static String? validate({
    required double distanceKm,
    required double averageSpeedKmh,
    required double maxRidingHoursPerDay,
    required int departureMinute,
    required int latestArrivalMinute,
    required int breakEveryKm,
    required int breakMinutes,
    required int lunchMinutes,
    required bool forceLunch,
  }) {
    if (!distanceKm.isFinite || distanceKm < 5 || distanceKm > 300 ||
        !averageSpeedKmh.isFinite || averageSpeedKmh <= 0 ||
        !maxRidingHoursPerDay.isFinite || maxRidingHoursPerDay <= 0) {
      return 'Revise a distância, a velocidade e o limite diário de pedal.';
    }
    final ridingMinutes = (distanceKm / averageSpeedKmh * 60).ceil();
    final maxMinutes = (maxRidingHoursPerDay * 60).round();
    if (ridingMinutes > maxMinutes) {
      return 'A meta exige cerca de ${ridingMinutes ~/ 60}h${(ridingMinutes % 60).toString().padLeft(2, '0')} de pedal, '
          'acima do limite de ${maxRidingHoursPerDay.toStringAsFixed(1)} h/dia. '
          'Reduza a distância, aumente o limite ou revise a velocidade.';
    }
    // Usa o mesmo cálculo do cartão diário: não esquece pausas e almoço.
    final prototype = BikeTripDayPlan(
      day: 1,
      startDistanceMeters: 0,
      endDistanceMeters: distanceKm * 1000,
      ridingDuration: Duration(minutes: ridingMinutes),
      stopLabel: 'Meta diária',
      stopLatitude: 0,
      stopLongitude: 0,
      stopKind: 'Estimativa',
      usesKnownPlace: false,
    );
    final schedule = BikeTripSchedule.forDay(
      day: prototype,
      departureMinute: departureMinute,
      breakEveryKm: breakEveryKm,
      breakDurationMinutes: breakMinutes,
      lunchDurationMinutes: lunchMinutes,
      forceLunch: forceLunch,
    );
    if (schedule.arrivalMinute > latestArrivalMinute) {
      return 'A meta chegaria por volta de '
          '${BikeTripDaySchedule.formatMinute(schedule.arrivalMinute)}, '
          'depois do limite ${BikeTripDaySchedule.formatMinute(latestArrivalMinute)}. '
          'Altere a saída, o limite de chegada, as pausas ou a meta.';
    }
    return null;
  }
}
