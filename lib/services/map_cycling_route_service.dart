import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/map_cycling_route.dart';
import '../models/map_travel_mode.dart';
import 'data_usage_service.dart';
import 'partner_api_key_service.dart';
import 'map_navigation_instruction_ptbr.dart';
import 'map_view_settings_service.dart';

/// Busca rotas viárias para o perfil de deslocamento escolhido. A tela mantém
/// direção direta como fallback quando a rede ou o serviço de roteamento não
/// estiver disponível. O nome da classe é preservado nesta etapa para reduzir
/// o risco de regressão durante a migração gradual do renderer de navegação.
class MapCyclingRouteService {
  MapCyclingRouteService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<MapCyclingRoute> fetch({
    required LatLng origin,
    required LatLng destination,
    MapTravelMode travelMode = MapTravelMode.bicycle,
  }) async {
    final routes = await fetchAlternatives(
      origin: origin,
      destination: destination,
      alternativeCount: 0,
      travelMode: travelMode,
    );
    return routes.first;
  }

  Future<List<MapCyclingRoute>> fetchAlternatives({
    required LatLng origin,
    required LatLng destination,
    int alternativeCount = 2,
    MapTravelMode travelMode = MapTravelMode.bicycle,
  }) async {
    await MapViewSettingsService.instance.initialize();
    final preference = MapViewSettingsService.instance.bikeSurface;
    final preferPaved = preference == BikeSurfacePreference.paved || preference == BikeSurfacePreference.rain;
    final safeAlternativeCount = alternativeCount.clamp(0, 2).toInt();
    // ORS é opcional (bicicleta, carro e caminhada); Valhalla continua como
    // fallback, inclusive quando a credencial foi revogada ou está sem cota.
    final candidates = <MapCyclingRoute>[];
    if (travelMode != MapTravelMode.motorcycle) {
      try {
        final key = await PartnerApiKeyService.instance.reveal(
          PartnerApiProvider.openrouteservice,
        );
        if (key != null && key.isNotEmpty) {
          final routes = await _fetchOrs(
            origin: origin, destination: destination, key: key,
            preference: preference, alternativeCount: safeAlternativeCount, travelMode: travelMode,
          ).timeout(const Duration(seconds: 20));
          final ranked = travelMode == MapTravelMode.bicycle ? rankSurfaceRoutes(routes, preference) : routes;
          candidates.addAll(ranked);
          if (ranked.isNotEmpty && (safeAlternativeCount == 0 || ranked.length > 1) &&
              !(travelMode == MapTravelMode.bicycle && preference == BikeSurfacePreference.rain && ranked.first.unknownSurfaceMeters > 0)) return ranked;
        }
      } catch (_) {
        // Não impedir a navegação por falha na API opcional.
      }
    }
    if (candidates.length <= 1 || (travelMode == MapTravelMode.bicycle && preference == BikeSurfacePreference.rain && candidates.first.unknownSurfaceMeters > 0)) {
      try {
        final key = await PartnerApiKeyService.instance.reveal(PartnerApiProvider.geoapify);
        if (key != null && key.isNotEmpty) {
          final routes = await _fetchGeoapify(origin, destination, key, preference, travelMode);
          final ranked = travelMode == MapTravelMode.bicycle ? rankSurfaceRoutes(routes, preference) : routes;
          for (final route in ranked) {
            if (!_duplicatesExistingRoute(candidates, route)) candidates.add(route);
          }
        }
      } catch (_) {
        // Chave opcional: Valhalla permanece disponível sem credencial.
      }
    }
    if (candidates.isNotEmpty) {
      return travelMode == MapTravelMode.bicycle ? rankSurfaceRoutes(candidates, preference) : candidates;
    }
    final payload = jsonEncode(<String, Object>{
      'locations': <Map<String, double>>[
        <String, double>{'lat': origin.latitude, 'lon': origin.longitude},
        <String, double>{'lat': destination.latitude, 'lon': destination.longitude},
      ],
      'costing': travelMode.valhallaCosting,
      if (travelMode == MapTravelMode.bicycle) 'costing_options': {
        'bicycle': {
          'bicycle_type': preferPaved ? 'Road' : 'Hybrid',
          'avoid_bad_surfaces': preferPaved ? 1.0 : 0.25,
          if (preference == BikeSurfacePreference.shortest) 'shortest': true,
        },
      },
      'units': 'km',
      'language': 'pt-BR',
      'alternates': safeAlternativeCount,
    });
    final uri = Uri.https(
      'valhalla1.openstreetmap.de',
      '/route',
      <String, String>{'json': payload},
    );
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.380');
    request.headers.set('X-Client-Id', 'com.vigiaia.app');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
    DataUsageService.instance.record(
      DataUsageModule.maps,
      received: utf8.encode(body).length,
      sent: utf8.encode(payload).length,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Roteamento indisponível (${response.statusCode})');
    }
    final routes = parseRoutes(body);
    return travelMode == MapTravelMode.bicycle ? rankSurfaceRoutes(routes, preference) : routes;
  }

  Future<List<MapCyclingRoute>> _fetchGeoapify(LatLng origin, LatLng destination,
      String key, BikeSurfacePreference preference, MapTravelMode travelMode) async {
    final preferPaved = preference == BikeSurfacePreference.paved || preference == BikeSurfacePreference.rain;
    final uri = Uri.https('api.geoapify.com', '/v1/routing', {
      'waypoints': '${origin.latitude},${origin.longitude}|${destination.latitude},${destination.longitude}',
      'mode': switch (travelMode) {
        MapTravelMode.bicycle => preferPaved ? 'road_bike' : 'bicycle',
        MapTravelMode.walking => 'walk',
        MapTravelMode.car => 'drive',
        MapTravelMode.motorcycle => 'motorcycle',
      },
      'type': travelMode == MapTravelMode.bicycle && preference == BikeSurfacePreference.shortest ? 'short' : 'balanced',
      'lang': 'pt', 'units': 'metric', 'format': 'geojson',
      if (travelMode == MapTravelMode.bicycle) 'details': 'route_details', 'apiKey': key,
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 10));
      DataUsageService.instance.record(DataUsageModule.maps, received: utf8.encode(body).length, sent: utf8.encode(uri.toString()).length);
      if (response.statusCode != HttpStatus.ok) throw HttpException('Geoapify HTTP ${response.statusCode}');
      return parseGeoapifyRoutes(body);
    } finally {
      client.close(force: true);
    }
  }

  List<MapCyclingRoute> parseGeoapifyRoutes(String body) {
    final data = jsonDecode(body);
    if (data is! Map || data['features'] is! List) throw const FormatException('Geoapify sem rotas');
    final routes = <MapCyclingRoute>[];
    for (final feature in (data['features'] as List).whereType<Map>()) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry is! Map || properties is! Map) continue;
      final lines = geometry['coordinates'];
      final legs = properties['legs'];
      // A requisição tem exatamente dois waypoints, portanto uma única perna.
      if (lines is! List || lines.length != 1 || lines.first is! List || legs is! List || legs.length != 1 || legs.first is! Map) continue;
      final points = <LatLng>[];
      for (final raw in lines.first as List) {
        if (raw is! List || raw.length < 2 || raw[0] is! num || raw[1] is! num) throw const FormatException('Coordenada Geoapify inválida');
        final lon = (raw[0] as num).toDouble();
        final lat = (raw[1] as num).toDouble();
        if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) throw const FormatException('Coordenada Geoapify inválida');
        points.add(LatLng(lat, lon));
      }
      final distance = (properties['distance'] as num?)?.toDouble() ?? 0;
      final time = (properties['time'] as num?)?.toDouble() ?? 0;
      if (points.length < 2 || !distance.isFinite || distance <= 0 || !time.isFinite || time < 0) continue;
      var paved = 0.0;
      var unpaved = 0.0;
      final maneuvers = <MapCyclingManeuver>[];
      final steps = (legs.first as Map)['steps'];
      if (steps is List) {
        for (final step in steps.whereType<Map>()) {
          final meters = (step['distance'] as num?)?.toDouble() ?? 0;
          if (meters.isFinite && meters > 0) {
            if (const {'paved', 'paved_smooth', 'paved_rough'}.contains(step['surface'])) paved += meters;
            if (const {'compacted', 'dirt', 'gravel', 'path', 'impassable'}.contains(step['surface'])) unpaved += meters;
          }
          final begin = (step['from_index'] as num?)?.toInt();
          final end = (step['to_index'] as num?)?.toInt();
          final instruction = step['instruction'];
          if (begin == null || end == null || begin < 0 || end < begin || end >= points.length || instruction is! Map || instruction['text'] is! String) continue;
          maneuvers.add(MapCyclingManeuver(instruction: MapNavigationInstructionPtBr.localize(instruction['text'] as String),
            beginShapeIndex: begin, endShapeIndex: end, distanceMeters: meters,
            durationSeconds: (step['time'] as num?)?.toDouble() ?? 0, streetName: step['name']?.toString()));
        }
      }
      if (paved + unpaved > distance) {
        final factor = distance / (paved + unpaved); paved *= factor; unpaved *= factor;
      }
      routes.add(MapCyclingRoute(provider: 'Geoapify', points: List.unmodifiable(points), distanceMeters: distance,
        durationSeconds: time, maneuvers: List.unmodifiable(maneuvers), pavedMeters: paved, unpavedMeters: unpaved));
    }
    if (routes.isEmpty) throw const FormatException('Geoapify sem rotas válidas');
    return routes;
  }

  Future<List<MapCyclingRoute>> _fetchOrs({
    required LatLng origin,
    required LatLng destination,
    required String key,
    required BikeSurfacePreference preference,
    required int alternativeCount,
    required MapTravelMode travelMode,
  }) async {
    final payload = jsonEncode(<String, Object>{
      'coordinates': <List<double>>[
        <double>[origin.longitude, origin.latitude],
        <double>[destination.longitude, destination.latitude],
      ],
      'elevation': true,
      if (travelMode == MapTravelMode.bicycle) 'extra_info': ['surface'],
      if (travelMode == MapTravelMode.bicycle && preference == BikeSurfacePreference.shortest) 'preference': 'shortest',
      if (alternativeCount > 0) 'alternative_routes': {'target_count': alternativeCount + 1, 'share_factor': 0.6, 'weight_factor': 1.6},
      'instructions': true,
      'language': 'pt',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(Uri.https(
        'api.heigit.org',
        travelMode == MapTravelMode.bicycle && preference != BikeSurfacePreference.paved && preference != BikeSurfacePreference.rain
            ? '/openrouteservice/v2/directions/cycling-regular/geojson'
            : '/openrouteservice/v2/directions/${switch (travelMode) {
          MapTravelMode.walking => 'foot-walking',
          MapTravelMode.car || MapTravelMode.motorcycle => 'driving-car',
          MapTravelMode.bicycle => preference == BikeSurfacePreference.paved || preference == BikeSurfacePreference.rain ? 'cycling-road' : 'cycling-regular',
        }}/geojson',
      )).timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, key);
      request.headers.set(HttpHeaders.acceptHeader, 'application/geo+json, application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.380');
      request.add(utf8.encode(payload));
      final response = await request.close().timeout(const Duration(seconds: 9));
      final body = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 9));
      DataUsageService.instance.record(
        DataUsageModule.maps,
        received: utf8.encode(body).length,
        sent: utf8.encode(payload).length,
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('ORS HTTP ${response.statusCode}');
      }
      return parseOrsAlternatives(body);
    } finally {
      client.close(force: true);
    }
  }

  /// GeoJSON ORS: coordenadas em [longitude, latitude, altitude?].
  /// Nunca interpreta altitude como latitude e mantém índices de manobras.
  static List<MapCyclingRoute> rankSurfaceRoutes(List<MapCyclingRoute> routes, BikeSurfacePreference preference) {
    final ranked = List<MapCyclingRoute>.of(routes);
    if (preference == BikeSurfacePreference.rain) {
      ranked.removeWhere((r) => r.unpavedMeters > 0);
    }
    if (preference == BikeSurfacePreference.paved || preference == BikeSurfacePreference.rain) {
      ranked.sort((a,b) => (a.unpavedMeters + a.unknownSurfaceMeters).compareTo(b.unpavedMeters + b.unknownSurfaceMeters));
    } else if (preference == BikeSurfacePreference.shortest) {
      ranked.sort((a,b) => a.distanceMeters.compareTo(b.distanceMeters));
    }
    return ranked;
  }

  MapCyclingRoute parseOrsGeoJson(String body) => parseOrsAlternatives(body).first;

  List<MapCyclingRoute> parseOrsAlternatives(String body) {
    final data = jsonDecode(body);
    if (data is! Map || data['features'] is! List ||
        (data['features'] as List).isEmpty) {
      throw const FormatException('GeoJSON ORS sem rota');
    }
    return (data['features'] as List).map(_parseOrsFeature).toList();
  }

  MapCyclingRoute _parseOrsFeature(dynamic feature) {
    if (feature is! Map) {
      throw const FormatException('Rota ORS inválida');
    }
    final geometry = feature['geometry'];
    if (geometry is! Map || geometry['coordinates'] is! List) {
      throw const FormatException('Geometria ORS inválida');
    }
    final points = <LatLng>[];
    final elevations = <double?>[];
    for (final raw in (geometry['coordinates'] as List)) {
      if (raw is! List || raw.length < 2 ||
          raw[0] is! num || raw[1] is! num) {
        continue;
      }
      final lat = (raw[1] as num).toDouble();
      final lon = (raw[0] as num).toDouble();
      if (lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180) {
        points.add(LatLng(lat, lon));
        final height = raw.length >= 3 && raw[2] is num
            ? (raw[2] as num).toDouble() : null;
        elevations.add(height != null && height.isFinite &&
            height >= -500 && height <= 9000 ? height : null);
      }
    }
    if (points.length < 2) {
      throw const FormatException('Rota ORS sem pontos');
    }
    final properties = feature['properties'];
    if (properties is! Map || properties['summary'] is! Map) {
      throw const FormatException('Rota ORS sem resumo');
    }
    final summary = properties['summary'] as Map;
    final distance = (summary['distance'] as num?)?.toDouble() ?? 0;
    final duration = (summary['duration'] as num?)?.toDouble() ?? 0;
    if (!distance.isFinite || distance <= 0 || !duration.isFinite || duration < 0) {
      throw const FormatException('Métricas ORS inválidas');
    }
    final maneuvers = <MapCyclingManeuver>[];
    final segments = properties['segments'];
    if (segments is List) {
      for (final segment in segments.whereType<Map>()) {
        final steps = segment['steps'];
        if (steps is! List) {
          continue;
        }
        for (final step in steps.whereType<Map>()) {
          final waypoints = step['way_points'];
          if (waypoints is! List || waypoints.length < 2) {
            continue;
          }
          final begin = (waypoints[0] as num?)?.toInt();
          final end = (waypoints[1] as num?)?.toInt();
          if (begin == null || end == null || begin < 0 ||
              end < begin || end >= points.length) {
            continue;
          }
          maneuvers.add(MapCyclingManeuver(
            instruction: MapNavigationInstructionPtBr.localize(
              step['instruction']?.toString() ?? 'Continuar',
            ),
            beginShapeIndex: begin,
            endShapeIndex: end,
            distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (step['duration'] as num?)?.toDouble() ?? 0,
            type: (step['type'] as num?)?.toInt(),
            streetName: step['name']?.toString(),
          ));
        }
      }
    }
    var paved = 0.0;
    var unpaved = 0.0;
    final extras = properties['extras'];
    final surface = extras is Map ? extras['surface'] : null;
    final values = surface is Map ? surface['summary'] : null;
    if (values is List) {
      for (final item in values.whereType<Map>()) {
        final kind = item['value'];
        final meters = item['distance'];
        if (meters is! num || !meters.isFinite || meters <= 0) continue;
        if (const {1,3,4,5,6,14}.contains(kind)) { paved += meters.toDouble(); }
        if (const {2,7,8,9,10,11,12,13,15,16,17,18}.contains(kind)) { unpaved += meters.toDouble(); }
      }
    }
    if (paved + unpaved > distance) {
      final factor = distance / (paved + unpaved);
      paved *= factor; unpaved *= factor;
    }
    return MapCyclingRoute(
      provider: 'OpenRouteService',
      points: List<LatLng>.unmodifiable(points),
      pavedMeters: paved, unpavedMeters: unpaved,
      distanceMeters: distance,
      durationSeconds: duration,
      maneuvers: List<MapCyclingManeuver>.unmodifiable(maneuvers),
      ascentMeters: (summary['ascent'] as num?)?.toDouble(),
      descentMeters: (summary['descent'] as num?)?.toDouble(),
      elevationsMeters: elevations.any((height) => height != null)
          ? List<double?>.unmodifiable(elevations) : const <double?>[],
    );
  }

  List<MapCyclingRoute> parseRoutes(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Resposta de rota inválida');
    }
    final root = Map<String, dynamic>.from(decoded);
    final routes = <MapCyclingRoute>[];

    final primaryTrip = root['trip'];
    if (primaryTrip is Map) {
      routes.add(_parseTrip(Map<String, dynamic>.from(primaryTrip)));
    }

    final alternates = root['alternates'];
    if (alternates is List) {
      for (final rawAlternate in alternates) {
        if (rawAlternate is! Map) continue;
        final alternate = Map<String, dynamic>.from(rawAlternate);
        final rawTrip = alternate['trip'];
        if (rawTrip is! Map) continue;
        final route = _parseTrip(Map<String, dynamic>.from(rawTrip));
        if (!_duplicatesExistingRoute(routes, route)) {
          routes.add(route);
        }
      }
    }

    if (routes.isEmpty) {
      throw const FormatException('Resposta de rota incompleta');
    }
    return List<MapCyclingRoute>.unmodifiable(routes);
  }

  MapCyclingRoute _parseTrip(Map<String, dynamic> trip) {
    final summary = trip['summary'] as Map<String, dynamic>?;
    final legs = trip['legs'] as List<dynamic>?;
    if (summary == null || legs == null || legs.isEmpty) {
      throw const FormatException('Resposta de rota incompleta');
    }
    final points = <LatLng>[];
    final maneuvers = <MapCyclingManeuver>[];
    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final leg = Map<String, dynamic>.from(rawLeg);
      final shape = leg['shape'] as String?;
      if (shape == null || shape.isEmpty) continue;
      final legPoints = _decodePolyline6(shape);
      if (legPoints.isEmpty) continue;

      var shapeOffset = points.length;
      if (points.isNotEmpty && _samePoint(points.last, legPoints.first)) {
        legPoints.removeAt(0);
        shapeOffset -= 1;
      }
      points.addAll(legPoints);

      final rawManeuvers = leg['maneuvers'];
      if (rawManeuvers is List) {
        for (final rawManeuver in rawManeuvers.whereType<Map>()) {
          final maneuver = Map<String, dynamic>.from(rawManeuver);
          final instruction = (maneuver['instruction'] as String?)?.trim();
          if (instruction == null || instruction.isEmpty) continue;
          final streetNames = maneuver['street_names'];
          final streetName = streetNames is List && streetNames.isNotEmpty
              ? streetNames.first.toString()
              : null;
          maneuvers.add(
            MapCyclingManeuver(
              instruction: MapNavigationInstructionPtBr.localize(instruction),
              beginShapeIndex:
                  shapeOffset + ((maneuver['begin_shape_index'] as num?)?.toInt() ?? 0),
              endShapeIndex:
                  shapeOffset + ((maneuver['end_shape_index'] as num?)?.toInt() ?? 0),
              distanceMeters:
                  ((maneuver['length'] as num?)?.toDouble() ?? 0) * 1000,
              durationSeconds: (maneuver['time'] as num?)?.toDouble() ?? 0,
              type: (maneuver['type'] as num?)?.toInt(),
              streetName: streetName,
            ),
          );
        }
      }
    }
    if (points.length < 2) throw const FormatException('Rota sem geometria');
    return MapCyclingRoute(
      provider: 'Valhalla',
      points: List<LatLng>.unmodifiable(points),
      distanceMeters: ((summary['length'] as num?)?.toDouble() ?? 0) * 1000,
      durationSeconds: (summary['time'] as num?)?.toDouble() ?? 0,
      maneuvers: List<MapCyclingManeuver>.unmodifiable(maneuvers),
    );
  }

  bool _duplicatesExistingRoute(
    List<MapCyclingRoute> existing,
    MapCyclingRoute candidate,
  ) {
    for (final route in existing) {
      if (route.points.length != candidate.points.length) continue;
      if (!_samePoint(route.points.first, candidate.points.first) ||
          !_samePoint(route.points.last, candidate.points.last)) {
        continue;
      }
      if (route.points.length == 2) return true;
      final midpoint = route.points.length ~/ 2;
      if (_samePoint(route.points[midpoint], candidate.points[midpoint])) {
        return true;
      }
    }
    return false;
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.0000001 &&
        (a.longitude - b.longitude).abs() < 0.0000001;
  }

  List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lon = 0;
    while (index < encoded.length) {
      final latValue = _decodeValue(encoded, index);
      index = latValue.$2;
      lat += latValue.$1;
      final lonValue = _decodeValue(encoded, index);
      index = lonValue.$2;
      lon += lonValue.$1;
      points.add(LatLng(lat / 1e6, lon / 1e6));
    }
    return points;
  }

  (int, int) _decodeValue(String encoded, int start) {
    var result = 0;
    var shift = 0;
    var index = start;
    int byte;
    do {
      if (index >= encoded.length) throw const FormatException('Polyline inválida');
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final value = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    return (value, index);
  }
}
