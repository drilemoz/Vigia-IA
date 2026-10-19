import 'package:flutter/services.dart';

/// Ponte para o transmissor MCRP nativo. Nao executa IA nem cria outra camera Flutter.
/// O servico de primeiro plano permanece vivo quando a Activity perde foco.
class NativeCameraTransmitterService {
  const NativeCameraTransmitterService._();

  static const MethodChannel _channel = MethodChannel('vigiaia/native_transmitter');

  static Future<NativeTransmitterStatus> status() async {
    final data = await _channel.invokeMapMethod<String, dynamic>('status');
    return NativeTransmitterStatus.fromMap(data ?? const <String, dynamic>{});
  }

  /// Deve ser chamado com a Activity visivel, apos permissao de CAMERA.
  static Future<void> start() async => _channel.invokeMethod<void>('start');
  static Future<void> stop() async => _channel.invokeMethod<void>('stop');
  static Future<void> toggleRecording() async => _channel.invokeMethod<void>('record');
  static Future<void> setScenePhotosEnabled(bool enabled) async =>
      _channel.invokeMethod<void>('scenePhotos', {'enabled': enabled});
}

class NativeTransmitterStatus {
  const NativeTransmitterStatus({
    required this.running, required this.starting, required this.releasing,
    required this.recording, required this.ready, required this.url,
    required this.phase, required this.error, required this.seconds,
    required this.scenePhotosEnabled, required this.scenePhotosSaved,
    required this.recorderAccepted, required this.recorderBusyDropped,
  });
  final bool running, starting, releasing, recording, ready;
  final String? url, error;
  final String phase;
  final int seconds;
  final bool scenePhotosEnabled;
  final int scenePhotosSaved, recorderAccepted, recorderBusyDropped;

  bool get busy => starting || releasing;

  factory NativeTransmitterStatus.fromMap(Map<String, dynamic> json) => NativeTransmitterStatus(
    running: json['running'] == true,
    starting: json['starting'] == true,
    releasing: json['releasing'] == true,
    recording: json['recording'] == true,
    ready: json['ready'] == true,
    url: json['url'] is String ? json['url'] as String : null,
    phase: json['phase'] is String ? json['phase'] as String : 'parado',
    error: json['error'] is String ? json['error'] as String : null,
    seconds: (json['seconds'] as num?)?.toInt() ?? 0,
    scenePhotosEnabled: json['scenePhotosEnabled'] == true,
    scenePhotosSaved: (json['scenePhotosSaved'] as num?)?.toInt() ?? 0,
    recorderAccepted: (json['recorderAccepted'] as num?)?.toInt() ?? 0,
    recorderBusyDropped: (json['recorderBusyDropped'] as num?)?.toInt() ?? 0,
  );
}
