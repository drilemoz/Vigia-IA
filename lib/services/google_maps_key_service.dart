import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Situação da chave do Google Maps no aparelho.
class GoogleMapsKeyStatus {
  const GoogleMapsKeyStatus({
    required this.configured,
    required this.sdkReady,
    required this.buildConfigured,
    required this.userConfigured,
    required this.source,
    required this.masked,
  });

  static const GoogleMapsKeyStatus none = GoogleMapsKeyStatus(
    configured: false,
    sdkReady: false,
    buildConfigured: false,
    userConfigured: false,
    source: 'none',
    masked: '',
  );

  /// Existe alguma chave salva no aparelho ou embutida no APK.
  final bool configured;
  /// Manifesto do APK possui uma chave Google Maps plausível (não valida Cloud).
  final bool sdkReady;
  final bool buildConfigured;
  final bool userConfigured;

  /// `user` (digitada pelo usuário), `build` (embutida no APK) ou `none`.
  final String source;
  final String masked;

  bool get isUserKey => source == 'user';
}

/// Guarda uma chave fornecida pelo usuário para gerenciamento criptografado.
/// Apenas a chave do manifesto do APK pode habilitar o Maps SDK; a chave
/// informada pela UI NÃO modifica o manifesto instalado.
/// Sem chave de build, o app mantém o mapa OSM e não cria um GoogleMap.
class GoogleMapsKeyService extends ChangeNotifier {
  GoogleMapsKeyService._();

  static final GoogleMapsKeyService instance = GoogleMapsKeyService._();

  static const MethodChannel _channel = MethodChannel('vigiaia/native');

  GoogleMapsKeyStatus _status = GoogleMapsKeyStatus.none;
  bool _initialized = false;

  GoogleMapsKeyStatus get status => _status;
  /// Proteção: não abrir GoogleMap somente porque uma chave foi salva na UI.
  bool get hasKey => _status.sdkReady;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await refresh();
  }

  Future<void> refresh() async {
    _status = await _readStatus();
    _initialized = true;
    notifyListeners();
  }

  /// Salva a chave. Texto vazio remove a chave do usuário.
  Future<GoogleMapsKeyStatus> save(String value) async {
    if (!Platform.isAndroid) return _status;
    final result = await _channel.invokeMapMethod<String, Object?>(
      'setGoogleMapsApiKey',
      <String, Object?>{'value': value.trim()},
    );
    _status = _parse(result);
    _initialized = true;
    notifyListeners();
    return _status;
  }

  Future<String?> reveal() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('revealGoogleMapsApiKey');
    } catch (_) {
      return null;
    }
  }

  /// Validação leve de formato; só o Google confirma se a chave é válida.
  static String? validate(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Cole a chave da API.';
    if (RegExp(r'\s').hasMatch(text)) return 'A chave não pode conter espaços.';
    if (text.length < 30) return 'A chave parece curta demais.';
    if (!text.startsWith('AIza')) {
      return 'Chaves do Google costumam começar com "AIza". Confira se copiou a chave certa.';
    }
    return null;
  }

  Future<GoogleMapsKeyStatus> _readStatus() async {
    if (!Platform.isAndroid) return GoogleMapsKeyStatus.none;
    try {
      final result = await _channel
          .invokeMapMethod<String, Object?>('googleMapsKeyStatus');
      return _parse(result);
    } catch (_) {
      return GoogleMapsKeyStatus.none;
    }
  }

  GoogleMapsKeyStatus _parse(Map<String, Object?>? data) {
    if (data == null) return GoogleMapsKeyStatus.none;
    return GoogleMapsKeyStatus(
      configured: data['configured'] == true,
      sdkReady: data['sdkReady'] == true,
      buildConfigured: data['buildConfigured'] == true,
      userConfigured: data['userConfigured'] == true,
      source: (data['source'] as String?) ?? 'none',
      masked: (data['masked'] as String?) ?? '',
    );
  }
}
