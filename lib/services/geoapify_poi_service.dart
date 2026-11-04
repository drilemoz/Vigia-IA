import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/map_route_point.dart';
import '../models/route_explorer_models.dart';
import 'data_usage_service.dart';
import 'partner_api_key_service.dart';

/// Geoapify Places como alternativa online aos pontos OSM/Overpass.
/// Uma consulta por ação: preserva limites de cota e uso offline.
class GeoapifyPoiService {
  const GeoapifyPoiService._();

  static const categories = <RouteExplorerCategory, String>{
    RouteExplorerCategory.fuel: 'service.vehicle.fuel',
    RouteExplorerCategory.restaurant: 'catering.restaurant',
    RouteExplorerCategory.health: 'healthcare.hospital',
    RouteExplorerCategory.water: 'amenity.drinking_water',
    RouteExplorerCategory.camping: 'camping.camp_site',
    RouteExplorerCategory.market: 'commercial.supermarket',
    RouteExplorerCategory.viewpoint: 'tourism.attraction.viewpoint',
  };

  static Future<List<RouteExplorerResult>?> search({
    required MapRoutePoint origin,
    required int radiusKm,
    required Set<RouteExplorerCategory> enabled,
  }) async {
    final key = await PartnerApiKeyService.instance.reveal(
      PartnerApiProvider.geoapify,
    );
    if (key == null || key.isEmpty) return null;
    final selected = <String>[
      for (final entry in categories.entries)
        if (enabled.contains(entry.key)) entry.value,
    ];
    if (selected.isEmpty) return null;
    final radiusMeters = (radiusKm * 1000).clamp(1000, 50000).toInt();
    final coords = '${origin.longitude.toStringAsFixed(4)},'
        '${origin.latitude.toStringAsFixed(4)}';
    final uri = Uri.https('api.geoapify.com', '/v2/places', <String, String>{
      'categories': selected.join(','),
      'filter': 'circle:$coords,$radiusMeters',
      'bias': 'proximity:$coords',
      'limit': '36',
      'lang': 'pt',
      'apiKey': key,
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.343');
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 8));
      DataUsageService.instance.record(DataUsageModule.nearby,
          received: utf8.encode(body).length);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Geoapify Places HTTP ${response.statusCode}');
      }
      return decode(body, origin: origin, enabled: enabled);
    } finally {
      client.close(force: true);
    }
  }

  static List<RouteExplorerResult> decode(String body, {
    required MapRoutePoint origin,
    required Set<RouteExplorerCategory> enabled,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['features'] is! List) {
      throw const FormatException('Resposta de POI Geoapify inválida');
    }
    final distance = const Distance();
    final results = <RouteExplorerResult>[];
    final seen = <String>{};
    for (final feature in (decoded['features'] as List).whereType<Map>()) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry is! Map || properties is! Map) {
        continue;
      }
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2 ||
          coords[0] is! num || coords[1] is! num) {
        continue;
      }
      final latitude = (coords[1] as num).toDouble();
      final longitude = (coords[0] as num).toDouble();
      if (!latitude.isFinite || !longitude.isFinite ||
          latitude.abs() > 90 || longitude.abs() > 180) {
        continue;
      }
      final tags = properties['categories'];
      if (tags is! List) {
        continue;
      }
      RouteExplorerCategory? category;
      for (final entry in categories.entries) {
        if (!enabled.contains(entry.key)) continue;
        if (tags.any((tag) => tag.toString() == entry.value ||
            tag.toString().startsWith('${entry.value}.'))) {
          category = entry.key;
          break;
        }
      }
      if (category == null) continue;
      final title = (properties['name'] ?? properties['address_line1'] ??
          category.label).toString().trim();
      final id = properties['place_id']?.toString() ??
          '${latitude.toStringAsFixed(5)}:${longitude.toStringAsFixed(5)}';
      if (!seen.add('$id:${category.name}')) continue;
      final address = properties['formatted']?.toString();
      results.add(RouteExplorerResult(
        id: 'geoapify:$id:${category.name}',
        category: category,
        title: title.isEmpty ? category.label : title,
        subtitle: address ?? '',
        latitude: latitude,
        longitude: longitude,
        distanceMeters: distance.as(LengthUnit.Meter,
          LatLng(origin.latitude, origin.longitude), LatLng(latitude, longitude)),
        source: 'geoapify',
        fetchedAt: DateTime.now(),
        address: address,
      ));
    }
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }
}
