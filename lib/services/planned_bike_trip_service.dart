import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/planned_bike_trip.dart';

/// Biblioteca independente da última prévia salva no mapa, sem permissões/GPS.
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
