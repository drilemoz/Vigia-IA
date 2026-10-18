import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../models/video_source_config.dart';
import 'native_platform_service.dart';

/// Para câmeras cadastradas, guarda apenas o ID. Fontes manuais são
/// preservadas somente criptografadas pelo Android Keystore.
/// Mantém a preferência mesmo quando a fonte fica temporariamente offline.
class LastLiveCameraService {
  LastLiveCameraService._();
  static final LastLiveCameraService instance = LastLiveCameraService._();
  File? _file;
  String? _value;
  String? _protectedManual;
  bool _loaded = false;

  Future<String?> read() async {
    if (_loaded) return _value;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}last_live_camera.json');
    _loaded = true;
    try {
      if (await _file!.exists()) {
        final data = jsonDecode(await _file!.readAsString());
        if (data is Map && data['cameraId'] is String) {
          final id = (data['cameraId'] as String).trim();
          if (id.isNotEmpty && id.length <= 160) _value = id;
          if (data['sourceSecret'] is String) _protectedManual = data['sourceSecret'] as String;
        }
      }
    } catch (_) { /* Uma preferência inválida nunca impede a câmera local. */ }
    return _value;
  }

  /// Fontes manuais sem ID do registro também podem ser retomadas.
  /// Dados sensíveis são persistidos somente criptografados pelo Android Keystore.
  Future<void> rememberManual(VideoSourceConfig source) async {
    await read();
    if (source.type == VideoSourceType.localCamera) {
      await remember('__local__');
      return;
    }
    try {
      final encrypted = await NativePlatformService.instance.protectSecret(
        jsonEncode(source.toJson()),
      );
      final file = _file!;
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode({
        'cameraId': '__manual__', 'sourceSecret': encrypted,
      }), flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
      _value = '__manual__';
      _protectedManual = encrypted;
    } catch (_) { /* Nunca salvar URL sensível em texto puro. */ }
  }

  Future<VideoSourceConfig?> readManual() async {
    await read();
    if (_value != '__manual__' || _protectedManual == null) return null;
    try {
      final text = await NativePlatformService.instance.unprotectSecret(_protectedManual);
      if (text == null) return null;
      return VideoSourceConfig.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  Future<void> remember(String? id) async {
    if (id == null || id.isEmpty || id.length > 160) return;
    await read();
    _value = id;
    _protectedManual = null;
    final file = _file!;
    try {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode({'cameraId': id}), flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    } catch (_) { /* Preferência de UX opcional. */ }
  }
}
