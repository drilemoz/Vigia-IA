import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/planned_bike_trip.dart';

/// Biblioteca compartilhada por Planejamento e Mapas, sem permissões/GPS.
class PlannedBikeTripService {
  const PlannedBikeTripService();

  static const int maximumTrips = 40;
  static const int maximumFileBytes = 20 * 1024 * 1024;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}vigia_planned_trips.json');
  }

  Future<List<PlannedBikeTrip>> load() async {
    final file = await _file();
    if (!await file.exists()) return const <PlannedBikeTrip>[];
    if (await file.length() > maximumFileBytes) {
      throw const FormatException('Biblioteca de viagens excede o limite de leitura');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['schema'] != 1 || decoded['trips'] is! List) {
      throw const FormatException('Formato de viagens não reconhecido');
    }
    final result = <PlannedBikeTrip>[];
    for (final item in (decoded['trips'] as List).take(maximumTrips)) {
      if (item is! Map) throw const FormatException('Viagem inválida');
      result.add(PlannedBikeTrip.fromJson(Map<String, dynamic>.from(item)));
    }
    return List<PlannedBikeTrip>.unmodifiable(result);
  }

  // Ações de Mapas e do editor podem ocorrer em sequência: nunca usar uma
  // lista antiga para sobrescrever silenciosamente rotas de outra entrada.
  static Future<void> _upsertQueue = Future<void>.value();

  Future<void> upsert(PlannedBikeTrip trip) {
    final operation = _upsertQueue.catchError((Object _) {}).then((_) async {
      final existing = await load(); // Se a biblioteca falhar, não sobrescreve.
      await saveAll(<PlannedBikeTrip>[
        trip,
        ...existing.where((item) => item.id != trip.id),
      ]);
    });
    _upsertQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> saveAll(List<PlannedBikeTrip> trips) async {
    final file = await _file();
    final encoded = jsonEncode(<String, Object?>{
      'schema': 1,
      'trips': [for (final trip in trips.take(maximumTrips)) trip.toJson()],
    });
    if (utf8.encode(encoded).length > maximumFileBytes) {
      throw const FormatException('Muitas rotas para a biblioteca local');
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(encoded, flush: true);
    // Em Android (POSIX), rename substitui o destino atomicamente.
    await temp.rename(file.path);
  }
}
