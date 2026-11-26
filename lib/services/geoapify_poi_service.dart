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

  static const categories = <RouteExplorerCategory, List<String>>{
    RouteExplorerCategory.fuel: ['service.vehicle.fuel'],
    RouteExplorerCategory.restaurant: ['catering.restaurant', 'catering.fast_food', 'catering.cafe'],
    RouteExplorerCategory.health: ['healthcare.hospital', 'healthcare.pharmacy', 'healthcare.clinic_or_praxis'],
    RouteExplorerCategory.water: ['amenity.drinking_water', 'amenity.toilet'],
    RouteExplorerCategory.stop: ['parking'],
    RouteExplorerCategory.camping: ['camping.camp_site', 'camping.caravan_site'],
    RouteExplorerCategory.riverBridge: ['tourism.sights.bridge'],
    RouteExplorerCategory.market: ['commercial.supermarket', 'commercial.convenience', 'commercial.food_and_drink'],
    RouteExplorerCategory.workshop: ['commercial.outdoor_and_sport.bicycle', 'service.vehicle.repair.car'],
    RouteExplorerCategory.viewpoint: ['tourism.attraction.viewpoint'],
  };

  static final _cache = <String, ({DateTime at, List<RouteExplorerResult> items})>{};

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
        if (enabled.contains(entry.key)) ...entry.value,
    ];
    if (selected.isEmpty) return null;
    final radiusMeters = (radiusKm * 1000).clamp(1000, 50000).toInt();
    final coords = '${origin.longitude.toStringAsFixed(4)},'
        '${origin.latitude.toStringAsFixed(4)}';
    final cacheKey = '$coords:$radiusMeters:${selected.join(',')}';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 15)) {
      return cached.items.map((item) => item.copyWith(
        distanceMeters: const Distance().as(LengthUnit.Meter,
          LatLng(origin.latitude, origin.longitude), LatLng(item.latitude, item.longitude)),
      )).toList(growable: false);
    }
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
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.384');
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 8));
      DataUsageService.instance.record(DataUsageModule.nearby,
          received: utf8.encode(body).length);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Geoapify Places HTTP ${response.statusCode}');
      }
      final items = decode(body, origin: origin, enabled: enabled);
      if (_cache.length >= 32) _cache.remove(_cache.keys.first);
      _cache[cacheKey] = (at: DateTime.now(), items: List<RouteExplorerResult>.unmodifiable(items));
      return items;
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
        if (tags.any((tag) => entry.value.any((value) =>
            tag.toString() == value || tag.toString().startsWith('$value.')))) {
          category = entry.key;
          break;
        }
      }
      if (category == null) continue;
      bool hasCategory(String value) => tags.any((tag) =>
          tag.toString() == value || tag.toString().startsWith('$value.'));
      final subtype = hasCategory('amenity.drinking_water') ? 'Ponto de água mapeado' :
          hasCategory('amenity.toilet') ? 'Banheiro mapeado' :
          hasCategory('parking') ? 'Estacionamento' : category.label;
      final title = (properties['name'] ?? subtype).toString().trim();
      final id = properties['place_id']?.toString() ??
          '${latitude.toStringAsFixed(5)}:${longitude.toStringAsFixed(5)}';
      if (!seen.add('$id:${category.name}')) continue;
      final address = properties['formatted']?.toString();
      final contact = properties['contact'];
      final datasource = properties['datasource'];
      final raw = datasource is Map ? datasource['raw'] : null;
      String? detail(String key) {
        final value = properties[key] ?? (contact is Map ? contact[key] : null) ??
            (raw is Map ? (raw[key] ?? raw['contact:$key']) : null);
        final text = value?.toString().trim();
        return text == null || text.isEmpty ? null : text;
      }
      results.add(RouteExplorerResult(
        id: 'geoapify:$id:${category.name}',
        category: category,
        title: title.isEmpty ? category.label : title,
        subtitle: [subtype, if (address != null && address.isNotEmpty) address].join(' · '),
        latitude: latitude,
        longitude: longitude,
        distanceMeters: distance.as(LengthUnit.Meter,
          LatLng(origin.latitude, origin.longitude), LatLng(latitude, longitude)),
        source: 'geoapify',
        fetchedAt: DateTime.now(),
        address: address,
        openingHours: detail('opening_hours'),
        phone: detail('phone'),
        website: detail('website'),
        operatorName: detail('operator'),
        amenities: <String>[
          if (hasCategory('amenity.drinking_water')) 'Água mapeada (potabilidade não verificada)',
          if (hasCategory('amenity.toilet')) 'Banheiro',
          if (detail('wheelchair') == 'yes') 'Acessibilidade mapeada',
          if (detail('fee') == 'no') 'Gratuito (informação cadastrada)',
          if (detail('fee') == 'yes') 'Pago (informação cadastrada)',
          if (detail('internet_access') == 'wlan') 'Wi-Fi mapeado',
          if (detail('power_supply') == 'yes') 'Energia elétrica mapeada',
        ],
      ));
    }
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }
}
