import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/map_destination_search.dart';
import '../models/map_route_point.dart';
import 'data_usage_service.dart';
import 'partner_api_key_service.dart';

/// Geocodificação opcional, somente após o usuário confirmar a busca.
/// Sem chave, erro ou cota: o chamador mantém Nominatim/índice offline.
class GeoapifyMapSearchService {
  const GeoapifyMapSearchService._();

  static Future<List<MapDestinationSearchResult>?> search({
    required String query,
    required MapRoutePoint origin,
    bool preferRegion = true,
  }) async {
    final key = await PartnerApiKeyService.instance.reveal(
      PartnerApiProvider.geoapify,
    );
    if (key == null || key.isEmpty) return null;
    final params = <String, String>{
      'text': query,
      'format': 'json',
      'lang': 'pt',
      'limit': '12',
      'apiKey': key,
      if (preferRegion)
        'bias': 'proximity:${origin.longitude.toStringAsFixed(2)},'
            '${origin.latitude.toStringAsFixed(2)}',
    };
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.getUrl(
        Uri.https('api.geoapify.com', '/v1/geocode/search', params),
      ).timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.347');
      final response = await request.close().timeout(const Duration(seconds: 6));
      final body = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 6));
      DataUsageService.instance.record(
        DataUsageModule.nearby,
        received: utf8.encode(body).length,
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Geoapify HTTP ${response.statusCode}');
      }
      return decodeResponse(body, origin);
    } finally {
      client.close(force: true);
    }
  }

  /// Parser puro, independente de rede/chave, para testes de contrato.
  static List<MapDestinationSearchResult> decodeResponse(
    String body,
    MapRoutePoint origin,
  ) {
    final root = jsonDecode(body);
    if (root is! Map || root['results'] is! List) {
      throw const FormatException('Resposta Geoapify inválida');
    }
    final results = <MapDestinationSearchResult>[];
    for (final raw in (root['results'] as List).whereType<Map>()) {
      final latitude = (raw['lat'] as num?)?.toDouble();
      final longitude = (raw['lon'] as num?)?.toDouble();
      if (latitude == null || longitude == null ||
          !latitude.isFinite || !longitude.isFinite ||
          latitude.abs() > 90 || longitude.abs() > 180) {
        continue;
      }
      final resultType = raw['result_type']?.toString();
      final kind = MapDestinationKindX.fromOsmType(resultType);
      final title = (raw['name'] ?? raw['city'] ?? raw['formatted'])
          ?.toString().trim() ?? '';
      if (title.isEmpty) {
        continue;
      }
      final subtitle = raw['formatted']?.toString().trim() ?? kind.label;
      // Distância real é calculada pelo serviço chamador com fórmula geodésica.
      final id = (raw['place_id']?.toString().isNotEmpty ?? false)
          ? raw['place_id'].toString()
          : '${latitude.toStringAsFixed(5)}:${longitude.toStringAsFixed(5)}';
      results.add(MapDestinationSearchResult(
        id: 'geoapify:$id',
        title: title,
        subtitle: subtitle,
        latitude: latitude,
        longitude: longitude,
        distanceMeters: 0,
        kind: kind,
        source: 'online',
      ));
    }
    return results;
  }
}
