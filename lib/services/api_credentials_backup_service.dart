import 'dart:convert';
import 'dart:io';

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

  /// Exportação SEM criptografia, somente após o usuário acionar Exportar.
  /// A chave incorporada ao APK nunca é lida nem incluída no arquivo.
  static const Map<String, String> envNames = <String, String>{
    'gemini': 'GEMINI_API_KEY',
    'googleMapsUser': 'GOOGLE_MAPS_USER_API_KEY',
    'stadia': 'STADIA_API_KEY',
    'geoapify': 'GEOAPIFY_API_KEY',
    'openrouteservice': 'OPENROUTESERVICE_API_KEY',
  };

  Future<Map<String, String>> _readConfiguredKeys() async {
    await OfflineMapService.instance.initialize();
    final keys = <String, String>{};
    final values = <String, String?>{
      'gemini': await GeminiMapService.instance.reveal(),
      'googleMapsUser': await GoogleMapsKeyService.instance.reveal(),
      'stadia': await OfflineMapService.instance.revealStadiaApiKey(),
      'geoapify': await PartnerApiKeyService.instance.reveal(
          PartnerApiProvider.geoapify),
      'openrouteservice': await PartnerApiKeyService.instance.reveal(
          PartnerApiProvider.openrouteservice),
    };
    for (final entry in values.entries) {
      final value = entry.value?.trim();
      if (value != null && value.isNotEmpty) keys[entry.key] = value;
    }
    return keys;
  }

  /// Texto UTF-8 no padrão NAME=valor, sem senha e sem transformação reversível.
  /// Destino escolhido pelo usuário com o seletor SAF do Android.
  Future<bool> exportPlaintextEnv() async {
    if (!Platform.isAndroid) {
      throw const FormatException('Exportação disponível no Android.');
    }
    final keys = await _readConfiguredKeys();
    if (keys.isEmpty) {
      throw const FormatException('Não há chaves cadastradas para exportar.');
    }
    final lines = <String>[
      '# Vigia IA — chaves exportadas sem criptografia (texto legível)',
      '# Não publique nem envie este arquivo para repositórios.',
    ];
    for (final entry in envNames.entries) {
      final value = keys[entry.key];
      if (value != null) lines.add('${entry.value}=$value');
    }
    if (keys.containsKey('gemini')) {
      lines.add('GEMINI_MODEL=${await GeminiMapService.instance.savedModel()}');
    }
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final result = await NativePlatformService.instance.saveBytesWithPicker(
      fileName: 'vigiaia-apis-$date.env',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(utf8.encode('${lines.join('\n')}\n')),
    );
    return result != null && result.isNotEmpty;
  }

  /// Importa .env/.txt legível e valida todos os campos antes de gravar.
  /// As chaves ausentes não são apagadas durante apply().
  Future<ApiCredentialsImport?> selectPlaintextEnv() async {
    if (!Platform.isAndroid) {
      throw const FormatException('Importação disponível no Android.');
    }
    final bytes = await _native.invokeMethod<Uint8List>('pickApiArchive');
    if (bytes == null) return null;
    if (bytes.isEmpty || bytes.length > 16384) {
      throw const FormatException('Arquivo de APIs vazio ou grande demais.');
    }
    String source;
    try {
      source = utf8.decode(bytes, allowMalformed: false).replaceFirst('\uFEFF', '');
    } on FormatException {
      throw const FormatException('Selecione um arquivo .env em texto UTF-8.');
    }
    return parsePlaintextEnv(source);
  }

  /// Parser puro, para testar sem Android nem revelar chaves nos erros.
  static ApiCredentialsImport parsePlaintextEnv(String source) {
    final reverse = <String, String>{
      for (final entry in envNames.entries) entry.value: entry.key,
    };
    final keys = <String, String>{};
    String? model;
    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) continue;
      if (line.startsWith('export ')) line = line.substring(7).trim();
      final equals = line.indexOf('=');
      if (equals <= 0) {
        throw const FormatException('Linha inválida: use NOME=valor.');
      }
      final name = line.substring(0, equals).trim();
      final value = line.substring(equals + 1).trim();
      if (name == 'GEMINI_MODEL') {
        if (model != null || !GeminiMapService.allowedModels.contains(value)) {
          throw const FormatException('Modelo Gemini duplicado ou inválido.');
        }
        model = value;
        continue;
      }
      final provider = reverse[name];
      if (provider == null) {
        throw FormatException('Nome não reconhecido no arquivo: $name');
      }
      if (keys.containsKey(provider)) {
        throw FormatException('Chave duplicada: $name');
      }
      if (value.isEmpty || value.length > 4096 || RegExp(r'\s').hasMatch(value)) {
        throw FormatException('Valor inválido para: $name');
      }
      keys[provider] = value;
    }
    if (keys.isEmpty) {
      throw const FormatException('O arquivo não contém chaves de API reconhecidas.');
    }
    return ApiCredentialsImport._(keys, model);
  }

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
    final restoredModel = backup._geminiModel;
    if (restoredModel != null) {
      await GeminiMapService.instance.saveModel(restoredModel);
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
