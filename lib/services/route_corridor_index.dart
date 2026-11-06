import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/map_destination_search.dart';

/// Localização geométrica aproximada: a menor distância em linha reta ao
/// traçado NÃO comprova que haja estrada de acesso, serviços ou passagem.
class RouteCorridorPlace {
  const RouteCorridorPlace({
    required this.place,
    required this.routeDistanceMeters,
    required this.proximityMeters,
  });

  final MapDestinationSearchResult place;
  final double routeDistanceMeters;
  final double proximityMeters;
}

/// Índice leve e determinístico para itinerários de centenas de quilômetros.
/// Não liga GPS, não usa rede e não cria localidades inexistentes.
class RouteCorridorIndex {
  const RouteCorridorIndex._();

  static const Distance _distance = Distance();

  /// Devolve pontos reais da rota espaçados por distância geográfica, não por
  /// índice de vértice (que varia conforme o roteador e as curvas).
  /// A amostragem é limitada para respeitar APIs públicas; NÃO garante a
  /// descoberta de todas as localidades intermediárias.
  static List<LatLng> searchSamples(
    List<LatLng> route, {
    double intervalMeters = 30000,
    int maximumSamples = 25,
  }) {
    if (route.length < 2) return List<LatLng>.of(route);
    final cumulative = _cumulative(route);
    final total = cumulative.last;
    if (total <= 0) return <LatLng>[route.first, route.last];
    final sections = (total / intervalMeters.clamp(1000, 150000))
        .ceil().clamp(1, math.max(1, maximumSamples - 1)).toInt();
    final output = <LatLng>[route.first];
    var edge = 1;
    for (var i = 1; i < sections; i++) {
      final goal = total * i / sections;
      while (edge < cumulative.length - 1 && cumulative[edge] < goal) {
        edge++;
      }
      final start = cumulative[edge - 1];
      final length = cumulative[edge] - start;
      final t = length <= 0 ? 0.0 :
          ((goal - start) / length).clamp(0.0, 1.0).toDouble();
      final a = route[edge - 1];
      final b = route[edge];
      output.add(LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ));
    }
    output.add(route.last);
    return List<LatLng>.unmodifiable(output);
  }

  /// Calcula a quilometragem progressiva e filtra locais fora do corredor.
  /// Limita a geometria a cerca de 500 segmentos para economizar bateria.
  static List<RouteCorridorPlace> locate({
    required List<LatLng> route,
    required double routeDistanceMeters,
    required Iterable<MapDestinationSearchResult> places,
    double maximumProximityMeters = 2500,
    int maximumResults = 100,
  }) {
    if (route.length < 2 || maximumResults <= 0) {
      return const <RouteCorridorPlace>[];
    }
    final skip = math.max(1, ((route.length - 1) / 500).ceil());
    final simplified = <LatLng>[route.first];
    for (var index = skip; index < route.length - 1; index += skip) {
      simplified.add(route[index]);
    }
    simplified.add(route.last);
    final distances = _cumulative(simplified);
    final total = distances.last;
    if (total <= 0) return const <RouteCorridorPlace>[];
    final scale = routeDistanceMeters.isFinite && routeDistanceMeters > 0
        ? routeDistanceMeters / total : 1.0;
    final seen = <String>{};
    final located = <RouteCorridorPlace>[];
    for (final place in places) {
      if (!place.latitude.isFinite || !place.longitude.isFinite ||
          place.latitude.abs() > 90 || place.longitude.abs() > 180 ||
          !seen.add(place.id)) {
        continue;
      }
      final latitude = place.latitude;
      final longitude = place.longitude;
      final candidate = LatLng(latitude, longitude);
      final cosLat = math.cos(latitude * math.pi / 180);
      var smallest = double.infinity;
      var progress = 0.0;
      for (var edge = 1; edge < simplified.length; edge++) {
        final a = simplified[edge - 1];
        final b = simplified[edge];
        final dx = (b.longitude - a.longitude) * cosLat;
        final dy = b.latitude - a.latitude;
        final px = (longitude - a.longitude) * cosLat;
        final py = latitude - a.latitude;
        final denominator = dx * dx + dy * dy;
        final t = denominator <= 1e-20 ? 0.0 :
            ((px * dx + py * dy) / denominator).clamp(0.0, 1.0).toDouble();
        final projection = LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        final meters = _distance.as(LengthUnit.Meter, candidate, projection);
        if (meters < smallest) {
          smallest = meters;
          progress = distances[edge - 1] +
              (distances[edge] - distances[edge - 1]) * t;
        }
      }
      if (smallest <= maximumProximityMeters) {
        located.add(RouteCorridorPlace(
          place: place,
          routeDistanceMeters: progress * scale,
          proximityMeters: smallest,
        ));
      }
    }
    located.sort((a, b) {
      final byPosition = a.routeDistanceMeters.compareTo(b.routeDistanceMeters);
      return byPosition != 0
          ? byPosition : a.proximityMeters.compareTo(b.proximityMeters);
    });
    return List<RouteCorridorPlace>.unmodifiable(located.take(maximumResults));
  }

  static List<double> _cumulative(List<LatLng> points) {
    final result = <double>[0];
    for (var i = 1; i < points.length; i++) {
      result.add(result.last + _distance.as(
        LengthUnit.Meter, points[i - 1], points[i]));
    }
    return result;
  }
}
