import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Credenciais opcionais protegidas pelo Keystore no código Android.
/// Credenciais opcionais agora utilizadas nas pesquisas e rotas sob demanda.
enum PartnerApiProvider { geoapify, openrouteservice }

class PartnerKeyStatus {
  const PartnerKeyStatus({required this.configured, required this.masked});
  final bool configured;
  final String masked;
}

class PartnerApiKeyService {
  PartnerApiKeyService._();
  static final PartnerApiKeyService instance = PartnerApiKeyService._();
  static const MethodChannel _channel = MethodChannel('vigiaia/native');

  static String? validate(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Cole a chave da API.';
    if (text.length > 4096 || RegExp(r'\s').hasMatch(text)) {
      return 'A chave não deve conter espaços nem ultrapassar 4096 caracteres.';
    }
    return null;
  }

  Future<PartnerKeyStatus> status(PartnerApiProvider provider) async {
    final data = await _channel.invokeMapMethod<String, Object?>(
      'partnerApiKeyStatus', {'provider': provider.name});
    return _parse(data);
  }

  Future<PartnerKeyStatus> save(PartnerApiProvider provider, String value) async {
    if (value.trim().isNotEmpty) {
      final problem = validate(value);
      if (problem != null) throw FormatException(problem);
    }
    final data = await _channel.invokeMapMethod<String, Object?>(
      'savePartnerApiKey', {'provider': provider.name, 'value': value.trim()});
    return _parse(data);
  }

  Future<String?> reveal(PartnerApiProvider provider) =>
      _channel.invokeMethod<String>('revealPartnerApiKey', {'provider': provider.name});

  PartnerKeyStatus _parse(Map<String, Object?>? data) => PartnerKeyStatus(
    configured: data?['configured'] == true,
    masked: data?['masked'] as String? ?? '',
  );

  /// Teste das operações integradas, somente por toque explícito; até quatro consultas.
  /// Nunca escreve corpo de erro, URL com a chave ou a chave em logs.
  Future<String> test(PartnerApiProvider provider) async {
    final key = await reveal(provider);
    if (key == null || key.isEmpty) return 'Salve uma chave antes de testar.';
    if (provider == PartnerApiProvider.geoapify) {
      final operations = <String, Uri>{
        'Busca de endereços': Uri.https('api.geoapify.com', '/v1/geocode/search', {
          'text': 'Brasília, Brasil', 'format': 'json', 'limit': '1', 'apiKey': key,
        }),
        'Endereço por coordenadas': Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
          'lat': '-15.7942', 'lon': '-47.8825', 'format': 'json', 'limit': '1', 'apiKey': key,
        }),
        'Pontos de interesse': Uri.https('api.geoapify.com', '/v2/places', {
          'categories': 'commercial.supermarket', 'filter': 'circle:-47.8825,-15.7942,2000',
          'limit': '1', 'apiKey': key,
        }),
        'Rota de bicicleta': Uri.https('api.geoapify.com', '/v1/routing', {
          'waypoints': '-15.7942,-47.8825|-15.7915,-47.8790',
          'mode': 'bicycle', 'apiKey': key,
        }),
      };
      final results = await Future.wait(operations.entries.map((entry) async {
        final result = await _testOperation(entry.value);
        return '${entry.key}: $result';
      }));
      return results.join('\n');
    }
    final profiles = <String, String>{
      'Bicicleta': 'cycling-regular', 'A pé': 'foot-walking', 'Carro': 'driving-car',
    };
    final results = await Future.wait(profiles.entries.map((entry) async {
      final uri = entry.value == 'cycling-regular'
          ? Uri.https('api.heigit.org', '/openrouteservice/v2/directions/cycling-regular/geojson')
          : Uri.https('api.heigit.org', '/openrouteservice/v2/directions/${entry.value}/geojson');
      return '${entry.key}: ${await _testOperation(uri, authorization: key)}';
    }));
    return results.join('\n');
  }

  Future<String> _testOperation(Uri uri, {String? authorization}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await (authorization != null
          ? client.postUrl(uri) : client.getUrl(uri)).timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      if (authorization != null) {
        request.headers.set('Authorization', authorization);
        request.headers.contentType = ContentType.json;
        request.write('{"coordinates":[[-47.8825,-15.7942],[-47.8790,-15.7915]]}');
      }
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final code = response.statusCode;
      // Drena no máximo o cabeçalho efetivo e fecha; não armazena ou exibe o corpo.
      await response.drain<void>().timeout(const Duration(seconds: 10));
      if (code == 200) return 'HTTP 200 · respondeu com sucesso.';
      if (code == 401 || code == 403) return 'Acesso negado (HTTP $code). Verifique a chave e suas restrições.';
      if (code == 410) return 'Endpoint desativado (HTTP 410). Atualize o aplicativo.';
      if (code == 429) return 'Limite de requisições atingido (HTTP 429).';
      return 'O serviço respondeu HTTP $code. Confira a configuração e tente mais tarde.';
    } on TimeoutException {
      return 'Teste expirou. Verifique a conexão e tente novamente.';
    } on SocketException {
      return 'Sem conexão com o serviço. Verifique a internet.';
    } on HandshakeException {
      return 'Falha na conexão TLS. Verifique a rede e a data do aparelho.';
    } catch (_) {
      return 'Não foi possível concluir o teste de conexão.';
    } finally {
      client.close(force: true);
    }
  }
}
