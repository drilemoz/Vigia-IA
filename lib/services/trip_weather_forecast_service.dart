import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_cycling_route.dart';
import '../models/trip_weather_day_forecast.dart';
import 'bike_trip_schedule.dart';
import 'data_usage_service.dart';

class TripWeatherFetchResult {
  const TripWeatherFetchResult({required this.forecasts,
    required this.eligibleDays, required this.errors});
  final List<TripWeatherDayForecast> forecasts;
  final int eligibleDays;
  final int errors;
}

/// Previsão amostrada na metade de cada etapa, chamada SOMENTE pelo botão.
/// O horário é estimado pelo plano e interpretado no fuso atual do aparelho.
/// A resposta Open-Meteo usa GMT para evitar parsing ambíguo de horário.
class TripWeatherForecastService {
  const TripWeatherForecastService();
  static const int maxQueriesPerTap = 8;
  static const int maxHorizonDays = 16;

  Future<TripWeatherFetchResult> fetch({
    required MapCyclingRoute route,
    required List<BikeTripDayPlan> days,
    required DateTime startDate,
    required int departureMinute,
    required int breakEveryKm,
    required int breakMinutes,
    required int lunchMinutes,
    required bool forceLunch,
  }) async {
    final now = DateTime.now().toUtc();
    final results = <TripWeatherDayForecast>[];
    var eligible = 0;
    var errors = 0;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      for (final day in days) {
        if (eligible >= maxQueriesPerTap) {
          break;
        }
        final schedule = BikeTripSchedule.forDay(
          day: day, departureMinute: departureMinute,
          breakEveryKm: breakEveryKm, breakDurationMinutes: breakMinutes,
          lunchDurationMinutes: lunchMinutes, forceLunch: forceLunch,
        );
        final targetLocal = DateTime(startDate.year, startDate.month,
            startDate.day + day.day - 1, 0,
            schedule.departureMinute + schedule.elapsedMinutes ~/ 2);
        final target = targetLocal.toUtc();
        if (target.isBefore(now.subtract(const Duration(hours: 1))) ||
            target.isAfter(now.add(const Duration(days: 15)))) {
          continue;
        }
        eligible++;
        final midpoint = _pointAtDistance(route,
            (day.startDistanceMeters + day.endDistanceMeters) / 2);
        try {
          results.add(await _fetchOne(
            client: client, at: midpoint, target: target, day: day.day,
          ));
        } catch (_) {
          errors++;
          // Sem conexão ou API indisponível: uma falha interrompe o lote.
          // Evita até oito tentativas seguidas desperdiçando bateria.
          break;
        }
      }
    } finally {
      client.close(force: true);
    }
    return TripWeatherFetchResult(forecasts: results,
        eligibleDays: eligible, errors: errors);
  }

  Future<TripWeatherDayForecast> _fetchOne({
    required HttpClient client,
    required LatLng at,
    required DateTime target,
    required int day,
  }) async {
    final date = '${target.year.toString().padLeft(4, '0')}-'
        '${target.month.toString().padLeft(2, '0')}-'
        '${target.day.toString().padLeft(2, '0')}';
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': at.latitude.toStringAsFixed(5),
      'longitude': at.longitude.toStringAsFixed(5),
      'hourly': 'temperature_2m,precipitation_probability,precipitation,'
          'wind_speed_10m,wind_gusts_10m,weather_code',
      'timezone': 'GMT',
      'start_date': date, 'end_date': date,
    });
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.359 (trip-weather)');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain();
      throw HttpException('Clima HTTP ${response.statusCode}');
    }
    final body = await utf8.decoder.bind(response).join()
        .timeout(const Duration(seconds: 10));
    DataUsageService.instance.record(DataUsageModule.weather,
        received: utf8.encode(body).length);
    final data = jsonDecode(body);
    if (data is! Map || data['hourly'] is! Map) {
      throw const FormatException('Clima sem valores horários');
    }
    final hourly = data['hourly'] as Map;
    final times = hourly['time'];
    if (times is! List || times.length > 30) {
      throw const FormatException('Clima sem série temporal válida');
    }
    var bestIndex = -1;
    var delta = const Duration(days: 30);
    for (var i = 0; i < times.length; i++) {
      final value = times[i];
      if (value is! String) {
        continue;
      }
      final time = DateTime.tryParse(
          value.endsWith('Z') ? value : '${value}Z');
      if (time == null) {
        continue;
      }
      final difference = time.difference(target).abs();
      if (difference < delta) {
        delta = difference;
        bestIndex = i;
      }
    }
    if (bestIndex < 0 || delta > const Duration(minutes: 90)) {
      throw const FormatException('Previsão fora do horário estimado');
    }
    double? value(String name, double low, double high) {
      final series = hourly[name];
      if (series is! List || bestIndex >= series.length) {
        return null;
      }
      final item = series[bestIndex];
      if (item is! num) {
        return null;
      }
      final number = item.toDouble();
      return number.isFinite && number >= low && number <= high ? number : null;
    }
    final code = value('weather_code', 0, 99);
    return TripWeatherDayForecast(
      day: day, estimatedAt: target, updatedAt: DateTime.now().toUtc(),
      rainProbabilityPercent: value('precipitation_probability', 0, 100),
      precipitationMm: value('precipitation', 0, 1000),
      windGustKmh: value('wind_gusts_10m', 0, 500),
      windSpeedKmh: value('wind_speed_10m', 0, 500),
      temperatureC: value('temperature_2m', -100, 70),
      weatherCode: code?.round(),
    );
  }

  static LatLng _pointAtDistance(MapCyclingRoute route, double requestedMeters) {
    if (route.points.length < 2 || route.distanceMeters <= 0) {
      return route.points.first;
    }
    const distance = Distance();
    var total = 0.0;
    final cumulative = <double>[0];
    for (var i = 1; i < route.points.length; i++) {
      total += distance.as(LengthUnit.Meter, route.points[i - 1], route.points[i]);
      cumulative.add(total);
    }
    if (total <= 0) {
      return route.points.first;
    }
    final target = requestedMeters.clamp(0.0, route.distanceMeters).toDouble() *
        total / route.distanceMeters;
    for (var i = 1; i < cumulative.length; i++) {
      if (cumulative[i] >= target) {
        final span = cumulative[i] - cumulative[i - 1];
        final t = span <= 0 ? 0.0 :
            ((target - cumulative[i - 1]) / span).clamp(0.0, 1.0).toDouble();
        final a = route.points[i - 1];
        final b = route.points[i];
        return LatLng(a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t);
      }
    }
    return route.points.last;
  }
}
