import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'gemini_map_service.dart';
import 'google_maps_key_service.dart';
import 'offline_map_service.dart';
import 'partner_api_key_service.dart';
import 'native_platform_service.dart';

/// Backup portável com senha, exclusivamente por ação explícita do usuário.
/// O formato é autenticado e cifrado pelo Android (AES-256-GCM/PBKDF2).
/// Não inclui MAPS_API_KEY do manifesto nem qualquer dado do Open-Meteo.
class ApiCredentialsBackupService {
  ApiCredentialsBackupService._();
  static final ApiCredentialsBackupService instance =
      ApiCredentialsBackupService._();
  static const MethodChannel _native = MethodChannel('vigiaia/native');
  static const String _format = 'vigiaia-encrypted-api-credentials';
  static const Set<String> _allowed = <String>{
    'gemini', 'googleMapsUser', 'stadia', 'geoapify', 'openrouteservice',
  };

  Future<bool> exportEncrypted(String password) async {
    if (!Platform.isAndroid) throw const FormatException('Recurso disponível no Android.');
    _validatePassword(password);
    final maps = GoogleMapsKeyService.instance;
    final offline = OfflineMapService.instance;
    final partner = PartnerApiKeyService.instance;
    await offline.initialize();
    final keys = <String, String>{};
    final geminiKey = await GeminiMapService.instance.reveal();
    final mapsKey = await maps.reveal();
    final stadiaKey = await offline.revealStadiaApiKey();
    final geoKey = await partner.reveal(PartnerApiProvider.geoapify);
    final orsKey = await partner.reveal(PartnerApiProvider.openrouteservice);
    void add(String name, String? key) {
      if (key != null && key.trim().isNotEmpty) keys[name] = key.trim();
    }
    add('gemini', geminiKey);
    add('googleMapsUser', mapsKey); // Apenas chave informada no app.
    add('stadia', stadiaKey);
    add('geoapify', geoKey);
    add('openrouteservice', orsKey);
    if (keys.isEmpty) {
      throw const FormatException('Não há chaves cadastradas para exportar.');
    }
    final model = await GeminiMapService.instance.savedModel();
    final plaintext = jsonEncode(<String, Object>{
      'format': _format,
      'version': 1,
      'keys': keys,
      'geminiModel': model,
    });
    final encrypted = await _native.invokeMethod<Uint8List>(
      'encryptApiArchive', <String, Object>{
        'password': password,
        'payload': plaintext,
      },
    );
    if (encrypted == null || encrypted.isEmpty) {
      throw StateError('A criptografia do arquivo falhou.');
    }
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final file = await NativePlatformService.instance.saveBytesWithPicker(
      fileName: 'vigiaia-apis-$date.vigiaapis',
      mimeType: 'application/octet-stream',
      bytes: encrypted,
    );
    return file != null && file.isNotEmpty;
  }

  /// Abre o SAF e valida integralmente a senha/arquivo ANTES de escrever chaves.
  /// Retorna somente os nomes para a tela de confirmação.
  Future<ApiCredentialsImport?> selectAndDecrypt(String password) async {
    if (!Platform.isAndroid) throw const FormatException('Recurso disponível no Android.');
    _validatePassword(password);
    final encrypted = await _native.invokeMethod<Uint8List>('pickApiArchive');
    if (encrypted == null) return null;
    if (encrypted.length > 65536 || encrypted.length < 53) {
      throw const FormatException('O arquivo não é um backup válido de APIs.');
    }
    final plain = await _native.invokeMethod<String>(
      'decryptApiArchive', <String, Object>{
        'bytes': encrypted,
        'password': password,
      },
    );
    if (plain == null || plain.length > 16384) {
      throw const FormatException('Arquivo inválido ou excede o tamanho permitido.');
    }
    final data = jsonDecode(plain);
    if (data is! Map<String, dynamic> || data['format'] != _format ||
        data['version'] != 1 || data['keys'] is! Map) {
      throw const FormatException('O formato do backup não é compatível.');
    }
    final raw = data['keys'] as Map;
    if (raw.isEmpty || raw.length > _allowed.length ||
        raw.keys.any((key) => key is! String || !_allowed.contains(key))) {
      throw const FormatException('Lista de provedores inválida no backup.');
    }
    final keys = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Credencial inválida no backup.');
      }
      final value = (entry.value as String).trim();
      if (value.isEmpty || value.length > 4096 || RegExp(r'\s').hasMatch(value)) {
        throw const FormatException('Formato de chave inválido no backup.');
      }
      keys[entry.key as String] = value;
    }
    final model = data['geminiModel'];
    if (model != null && (model is! String ||
        !GeminiMapService.allowedModels.contains(model))) {
      throw const FormatException('Modelo Gemini inválido no backup.');
    }
    return ApiCredentialsImport._(keys, model as String?);
  }

  Future<void> apply(ApiCredentialsImport backup) async {
    final keys = backup._keys;
    // Ausência de credencial no backup NUNCA apaga a chave no aparelho.
    if (keys.containsKey('gemini')) {
      await GeminiMapService.instance.save(keys['gemini']!);
    }
    if (keys.containsKey('googleMapsUser')) {
      await GoogleMapsKeyService.instance.save(keys['googleMapsUser']!);
    }
    if (keys.containsKey('stadia')) {
      await OfflineMapService.instance.configureStadiaApiKey(keys['stadia']!);
    }
    if (keys.containsKey('geoapify')) {
      await PartnerApiKeyService.instance.save(
          PartnerApiProvider.geoapify, keys['geoapify']!);
    }
    if (keys.containsKey('openrouteservice')) {
      await PartnerApiKeyService.instance.save(
          PartnerApiProvider.openrouteservice, keys['openrouteservice']!);
    }
    if (backup._geminiModel != null) {
      await GeminiMapService.instance.saveModel(backup._geminiModel!);
    }
  }

  static void _validatePassword(String value) {
    if (value.length < 10 || value.length > 256) {
      throw const FormatException('A senha deve ter de 10 a 256 caracteres.');
    }
  }
}

class ApiCredentialsImport {
  const ApiCredentialsImport._(this._keys, this._geminiModel);
  final Map<String, String> _keys;
  final String? _geminiModel;
  List<String> get providers => List<String>.unmodifiable(_keys.keys);
  bool get includesGeminiModel => _geminiModel != null;
}
