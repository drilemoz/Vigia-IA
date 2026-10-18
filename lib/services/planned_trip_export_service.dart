import 'dart:convert';

import '../models/planned_bike_trip.dart';

/// Exporta apenas dados já calculados/salvos, sem rede ou GPS.
/// GPX é um traçado (track), não um arquivo de navegação turn-by-turn.
class PlannedTripExportService {
  const PlannedTripExportService._();

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String toGpx(PlannedBikeTrip trip) {
    final route = trip.selectedRoute;
    if (route.points.length < 2 || !route.distanceMeters.isFinite) {
      throw const FormatException('Rota sem geometria válida para exportação');
    }
    // Um limite evita envio de ByteArrays arbitrariamente grandes ao Android.
    if (route.points.length > 60000) {
      throw const FormatException('Rota grande demais para exportação GPX');
    }
    final origin = trip.origin;
    final destination = trip.destination;
    final tripName = '${origin.title} → ${destination.title}';
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="Vigia IA" xmlns="http://www.topografix.com/GPX/1/1">')
      ..writeln('  <metadata><name>${_xml(tripName)}</name></metadata>')
      ..writeln('  <wpt lat="${origin.latitude}" lon="${origin.longitude}"><name>${_xml(origin.title)}</name></wpt>')
      ..writeln('  <wpt lat="${destination.latitude}" lon="${destination.longitude}"><name>${_xml(destination.title)}</name></wpt>')
      ..writeln('  <trk><name>${_xml(tripName)}</name><trkseg>');
    for (final point in route.points) {
      if (!point.latitude.isFinite || !point.longitude.isFinite ||
          point.latitude.abs() > 90 || point.longitude.abs() > 180) {
        throw const FormatException('Coordenadas inválidas no percurso');
      }
      buffer.writeln('    <trkpt lat="${point.latitude.toStringAsFixed(6)}" lon="${point.longitude.toStringAsFixed(6)}"/>');
    }
    buffer.writeln('  </trkseg></trk>');
    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  /// JSON integral da viagem, com opções de pedalada e alternativas.
  /// Compatível com os dados produzidos por PlannedBikeTrip.toJson().
  static String toJson(PlannedBikeTrip trip) => const JsonEncoder.withIndent('  ').convert({
    'schema': 1,
    'exportedBy': 'Vigia IA',
    'trip': trip.toJson(),
  });
}
