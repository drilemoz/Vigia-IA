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

  /// Teste mínimo de uma única consulta, somente por toque explícito.
  /// Nunca escreve corpo de erro, URL com a chave ou a chave em logs.
  Future<String> test(PartnerApiProvider provider) async {
    final key = await reveal(provider);
    if (key == null || key.isEmpty) return 'Salve uma chave antes de testar.';
    final uri = switch (provider) {
      PartnerApiProvider.geoapify => Uri.https(
        'api.geoapify.com', '/v1/geocode/search', {
          'text': 'Brasília, Brasil', 'format': 'json', 'limit': '1',
          'apiKey': key,
        }),
      PartnerApiProvider.openrouteservice => Uri.https(
        'api.openrouteservice.org', '/v2/directions/cycling-regular', {
          'start': '-47.8825,-15.7942', 'end': '-47.8790,-15.7915',
        }),
    };
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      if (provider == PartnerApiProvider.openrouteservice) {
        request.headers.set('Authorization', key);
      }
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final code = response.statusCode;
      // Drena no máximo o cabeçalho efetivo e fecha; não armazena ou exibe o corpo.
      await response.drain<void>().timeout(const Duration(seconds: 10));
      if (code == 200) return 'API respondeu com sucesso (HTTP 200). O uso no mapa depende de conexão, cota e operação disponível.';
      if (code == 401 || code == 403) return 'Acesso negado (HTTP $code). Verifique a chave e suas restrições.';
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
