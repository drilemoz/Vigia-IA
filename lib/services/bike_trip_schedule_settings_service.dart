import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Preferências de horário/pausas comuns à entrada Home e à entrada Mapas.
/// Mantidas separadas das preferências de velocidade do MapViewSettingsService.
class BikeTripScheduleSettings {
  const BikeTripScheduleSettings({
    this.departureMinute = 420,
    this.breakEveryKm = 20,
    this.breakMinutes = 10,
    this.lunchMinutes = 40,
    this.forceLunch = false,
  });

  final int departureMinute;
  final int breakEveryKm;
  final int breakMinutes;
  final int lunchMinutes;
  final bool forceLunch;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'departureMinute': departureMinute,
    'breakEveryKm': breakEveryKm,
    'breakMinutes': breakMinutes,
    'lunchMinutes': lunchMinutes,
    'forceLunch': forceLunch,
  };

  factory BikeTripScheduleSettings.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1) {
      throw const FormatException('Preferências de viagem incompatíveis');
    }
    return BikeTripScheduleSettings(
      departureMinute: ((json['departureMinute'] as num?)?.toInt() ?? 420).clamp(0, 1439).toInt(),
      breakEveryKm: ((json['breakEveryKm'] as num?)?.toInt() ?? 20).clamp(5, 100).toInt(),
      breakMinutes: ((json['breakMinutes'] as num?)?.toInt() ?? 10).clamp(0, 60).toInt(),
      lunchMinutes: ((json['lunchMinutes'] as num?)?.toInt() ?? 40).clamp(0, 120).toInt(),
      forceLunch: json['forceLunch'] == true,
    );
  }
}

class BikeTripScheduleSettingsService {
  BikeTripScheduleSettingsService._();

  static final instance = BikeTripScheduleSettingsService._();
  BikeTripScheduleSettings _value = const BikeTripScheduleSettings();
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();

  BikeTripScheduleSettings get value => _value;

  Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    return File('${root.path}${Platform.pathSeparator}bike_trip_schedule_settings.json');
  }

  Future<void> initialize() => _loading ??= _read();

  Future<void> _read() async {
    final file = await _file();
    if (!await file.exists()) return;
    if (await file.length() > 8192) {
      throw const FormatException('Preferências de viagem excedem limite');
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) throw const FormatException('Preferências inválidas');
      _value = BikeTripScheduleSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // Não confundir preferências corrompidas com perda da biblioteca de rotas.
      // Renomeia o original antes de utilizar valores conservadores.
      final backup = File('${file.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}');
      await file.rename(backup.path);
      _value = const BikeTripScheduleSettings();
    }
  }

  Future<void> save(BikeTripScheduleSettings next) async {
    await initialize();
    _value = next;
    // Serializa gravações rápidas de sliders/seletores sem perder o último valor.
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(_value.toJson()), flush: true);
      await temp.rename(file.path);
    });
    await _writes;
  }
}
