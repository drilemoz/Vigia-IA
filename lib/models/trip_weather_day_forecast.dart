/// Previsão pontual obtida por ação explícita. Não é alerta oficial.
/// `estimatedAt` e `updatedAt` são instantes absolutos, com fuso no JSON.
class TripWeatherDayForecast {
  const TripWeatherDayForecast({
    required this.day,
    required this.estimatedAt,
    required this.updatedAt,
    this.rainProbabilityPercent,
    this.precipitationMm,
    this.windGustKmh,
    this.windSpeedKmh,
    this.temperatureC,
    this.weatherCode,
  });
  final int day;
  final DateTime estimatedAt;
  final DateTime updatedAt;
  final double? rainProbabilityPercent;
  final double? precipitationMm;
  final double? windGustKmh;
  final double? windSpeedKmh;
  final double? temperatureC;
  final int? weatherCode;

  Map<String, Object?> toJson() => {
    'day': day,
    'estimatedAt': estimatedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'rainProbabilityPercent': rainProbabilityPercent,
    'precipitationMm': precipitationMm,
    'windGustKmh': windGustKmh,
    'windSpeedKmh': windSpeedKmh,
    'temperatureC': temperatureC,
    'weatherCode': weatherCode,
  };

  factory TripWeatherDayForecast.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final at = DateTime.tryParse(json['estimatedAt']?.toString() ?? '');
    final updated = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (day is! int || day < 1 || day > 180 || at == null || updated == null) {
      throw const FormatException('Previsão de etapa inválida');
    }
    double? number(String key, double minimum, double maximum) {
      final raw = json[key];
      if (raw is! num) {
        return null;
      }
      final value = raw.toDouble();
      return value.isFinite && value >= minimum && value <= maximum ? value : null;
    }
    final code = json['weatherCode'];
    return TripWeatherDayForecast(
      day: day,
      estimatedAt: at.toUtc(),
      updatedAt: updated.toUtc(),
      rainProbabilityPercent: number('rainProbabilityPercent', 0, 100),
      precipitationMm: number('precipitationMm', 0, 1000),
      windGustKmh: number('windGustKmh', 0, 500),
      windSpeedKmh: number('windSpeedKmh', 0, 500),
      temperatureC: number('temperatureC', -100, 70),
      weatherCode: code is int && code >= 0 && code <= 99 ? code : null,
    );
  }
}
