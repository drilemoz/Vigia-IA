import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Gemini é opcional; não substitui Nominatim/OSM, roteamento ou dados offline.
/// A chave nunca é colocada em URL, log, relatório ou preferências Dart.
class GeminiMapService {
  GeminiMapService._();
  static final GeminiMapService instance = GeminiMapService._();
  static const MethodChannel _native = MethodChannel('vigiaia/native');
  static const String defaultModel = 'gemini-3.5-flash-lite';
  static const String advancedModel = 'gemini-3.8-flash';
  static const List<String> allowedModels = [defaultModel, advancedModel];
  static const String endpoint = 'generativelanguage.googleapis.com';

  Future<String> savedModel() async {
    final name = await _native.invokeMethod<String>('geminiModel');
    return allowedModels.contains(name) ? name! : defaultModel;
  }

  Future<void> saveModel(String model) async {
    if (!allowedModels.contains(model)) throw const FormatException('Modelo inválido.');
    await _native.invokeMethod<String>('saveGeminiModel', <String, Object?>{'value': model});
  }

  Future<GeminiKeyStatus> status() async {
    final response = await _native.invokeMapMethod<String, Object?>('geminiKeyStatus');
    return GeminiKeyStatus(
      configured: response?['configured'] == true,
      masked: response?['masked'] as String? ?? '',
    );
  }

  Future<GeminiKeyStatus> save(String key) async {
    final value = key.trim();
    if (value.isNotEmpty && (value.length > 4096 || RegExp(r'\s').hasMatch(value))) {
      throw const FormatException('A chave não pode ter espaços ou ser muito longa.');
    }
    final response = await _native.invokeMapMethod<String, Object?>(
      'saveGeminiApiKey', <String, Object?>{'value': value});
    return GeminiKeyStatus(
      configured: response?['configured'] == true,
      masked: response?['masked'] as String? ?? '',
    );
  }

  Future<String?> reveal() => _native.invokeMethod<String>('revealGeminiApiKey');

  Future<String> test({String? model}) async {
    final chosenModel = model ?? await savedModel();
    final answer = await _request(
      'Responda apenas: OK', model: chosenModel, maxOutputTokens: 160);
    if (answer.trim().isEmpty) throw const FormatException('Resposta vazia do Gemini.');
    return 'Conexão validada com $chosenModel.';
  }

  Future<GeminiMapSuggestion> interpret(String userRequest, {
    String? model,
  }) async {
    final request = userRequest.trim();
    if (request.length < 3 || request.length > 500) {
      throw const FormatException('Descreva o local desejado em até 500 caracteres.');
    }
    final answer = await _request(request, model: model ?? await savedModel(),
      maxOutputTokens: 900,
      instruction: '''Você é um assistente de consultas cartográficas para cicloviajantes brasileiros.
Converta a pergunta em um texto curto para pesquisar lugares existentes no OpenStreetMap via Nominatim.
NÃO invente coordenadas, distância, endereços, estabelecimentos, horários, segurança ou funcionamento.
Responda SOMENTE JSON com as chaves search_query e explanation. search_query deve ser uma expressão de busca geográfica concreta e concisa, idealmente "categoria, município, estado"; explanation, uma frase curta em português avisando o que será pesquisado. Não inclua markdown. Se a pergunta não identificar região, preserve o local se informado, sem presumir cidade ou posição exata.''');
    return GeminiMapSuggestion.parse(answer);
  }

  Future<String> _request(String input, {
    required String model,
    int maxOutputTokens = 200,
    String? instruction,
  }) async {
    if (!allowedModels.contains(model)) {
      throw const FormatException('Modelo Gemini não permitido.');
    }
    final apiKey = await reveal();
    if (apiKey == null || apiKey.isEmpty) {
      throw const GeminiMapException('Cadastre sua chave Gemini nas Configurações.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.https(endpoint, '/v1beta/models/$model:generateContent');
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('x-goog-api-key', apiKey);
      request.headers.set('x-goog-api-client', 'vigiaia-android/1.0.347');
      final payload = <String, Object?>{
        if (instruction != null) 'systemInstruction': <String, Object?>{
          'parts': <Object>[<String, String>{'text': instruction}],
        },
        'contents': <Object>[<String, Object>{
          'role': 'user',
          'parts': <Object>[<String, String>{'text': input}],
        }],
        'generationConfig': <String, Object>{
          'maxOutputTokens': maxOutputTokens,
          if (instruction != null) 'responseMimeType': 'application/json',
        },
      };
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(const Duration(seconds: 25));
      // Não exportar o corpo de erros HTTP: alguns provedores o incluem nos logs.
      if (response.contentLength > 1024 * 1024) {
        throw const GeminiMapException('Resposta maior que o limite permitido.');
      }
      final body = await response.transform(utf8.decoder).join().timeout(
        const Duration(seconds: 25));
      if (body.length > 1024 * 1024) {
        throw const GeminiMapException('Resposta maior que o limite permitido.');
      }
      if (response.statusCode == 400 || response.statusCode == 404) {
        throw const GeminiMapException('Modelo ou solicitação não disponível. Tente outro modelo.');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const GeminiMapException('Chave sem autorização para Gemini. Confira a chave e as restrições.');
      }
      if (response.statusCode == 429) {
        throw const GeminiMapException('Limite de uso Gemini atingido. Tente mais tarde.');
      }
      if (response.statusCode != 200) {
        throw GeminiMapException('Gemini indisponível (HTTP ${response.statusCode}).');
      }
      final parsed = jsonDecode(body);
      if (parsed is! Map<String, dynamic>) {
        throw const GeminiMapException('Resposta inesperada do serviço.');
      }
      final candidates = parsed['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const GeminiMapException('Gemini não retornou uma resposta.');
      }
      final first = candidates.first;
      if (first is! Map) throw const GeminiMapException('Resposta inválida.');
      final content = first['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List) throw const GeminiMapException('Gemini não retornou texto.');
      final output = parts.whereType<Map>().map((p) => p['text'])
          .whereType<String>().join('\n').trim();
      if (output.isEmpty) throw const GeminiMapException('Resposta Gemini vazia.');
      return output;
    } on SocketException {
      throw const GeminiMapException('Sem conexão com a API Gemini.');
    } on TimeoutException {
      throw const GeminiMapException('Tempo de resposta da API esgotado.');
    } finally {
      client.close(force: true);
    }
  }
}

class GeminiKeyStatus {
  const GeminiKeyStatus({required this.configured, required this.masked});
  final bool configured;
  final String masked;
}

class GeminiMapSuggestion {
  const GeminiMapSuggestion({required this.searchQuery, required this.explanation});
  final String searchQuery;
  final String explanation;

  static GeminiMapSuggestion parse(String raw) {
    final jsonText = raw.trim().replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$', caseSensitive: false), '');
    final data = jsonDecode(jsonText);
    if (data is! Map<String, dynamic>) throw const FormatException('Resposta fora do formato esperado.');
    final query = (data['search_query'] as String? ?? '').trim();
    final explanation = (data['explanation'] as String? ?? '').trim();
    if (query.length < 2 || query.length > 180 || RegExp(r'[\r\n]').hasMatch(query)) {
      throw const FormatException('Gemini não forneceu uma busca geográfica válida.');
    }
    return GeminiMapSuggestion(searchQuery: query, explanation: explanation);
  }
}

class GeminiMapException implements Exception {
  const GeminiMapException(this.message);
  final String message;
  @override
  String toString() => message;
}
