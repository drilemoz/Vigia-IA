import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_metadata.dart';
import '../utils/diagnostic_redactor.dart';
import 'error_log_service.dart';
import 'native_platform_service.dart';
import 'runtime_health_service.dart';

/// Always on. Reads cached app metrics only; never starts cameras, GPS or audio.
class AutomaticDiagnosticsService with WidgetsBindingObserver {
  AutomaticDiagnosticsService._();
  static final instance = AutomaticDiagnosticsService._();
  static const _channel = MethodChannel('vigiaia/native');
  bool _started = false;
  bool _busy = false;
  bool _foreground = true;
  String _lifecycle = 'starting';
  Timer? _timer;
  int _frames = 0;
  int _slowFrames = 0;
  int _maxFrameMs = 0;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
    ErrorLogService.instance.onRecorded = (entry) {
      unawaited(
        _send('diagnosticEvent', <String, Object?>{
          'source': entry.source,
          'detail': DiagnosticRedactor.text(
            '${entry.level.name}: ${entry.message}\n${entry.details ?? ''}\n${entry.context}',
          ),
          'unhandled': entry.context['nãoTratado'] == 'true',
        }),
      );
    };
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_foreground || RuntimeHealthService.instance.monitoringActive) {
        unawaited(_heartbeat());
      }
    });
    unawaited(_heartbeat());
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames++;
      final ms = timing.totalSpan.inMilliseconds;
      if (ms > 32) _slowFrames++;
      if (ms > _maxFrameMs) _maxFrameMs = ms;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state.name;
    _foreground = state == AppLifecycleState.resumed;
    unawaited(
      _send('diagnosticEvent', {
        'source': 'ciclo Flutter',
        'detail': state.name,
      }),
    );
    unawaited(_heartbeat());
  }

  Future<void> _send(String method, Map<String, Object?> args) async {
    try {
      await _channel
          .invokeMethod<void>(method, args)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Diagnostics never prevent using the app; native recorder continues. */
    }
  }

  Future<void> _heartbeat() async {
    if (_busy) return;
    _busy = true;
    try {
      final runtime = RuntimeHealthService.instance;
      final value = <String, Object?>{
        'at': DateTime.now().toIso8601String(),
        'lifecycle': _lifecycle,
        'monitoring': runtime.monitoringActive,
        'source': runtime.source,
        'camera': runtime.cameraActive,
        'aiReady': runtime.aiReady,
        'cameraHealth': runtime.cameraHealth.name,
        'fps': runtime.fps,
        'lastFrame': runtime.lastFrameAt?.toIso8601String(),
        'lan': runtime.lanActive,
        'clients': runtime.lanClients,
        'lanLastFrame': runtime.lanLastFrameAt?.toIso8601String(),
        'lanError': runtime.lanError,
        'uiFrames': _frames,
        'uiFramesOver32ms': _slowFrames,
        'uiMaxFrameMs': _maxFrameMs,
        'loggedProblems': ErrorLogService.instance.problemCount,
      };
      _frames = 0;
      _slowFrames = 0;
      _maxFrameMs = 0;
      await _send('diagnosticHeartbeat', {
        'value': DiagnosticRedactor.text(jsonEncode(value)),
      });
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, Object?>> capture() async {
    try {
      final raw = await _channel
          .invokeMethod<String>('automaticDiagnostics')
          .timeout(const Duration(seconds: 5));
      final decoded = jsonDecode(raw ?? '{}');
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      /* Older native build / unsupported platform. */
    }
    return <String, Object?>{'available': false};
  }

  Future<bool> acknowledge(String id) async {
    try {
      return await _channel
              .invokeMethod<bool>('acknowledgeDiagnostic', {'id': id})
              .timeout(const Duration(seconds: 5)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Exports frozen evidence even if the camera/GPS/health subsystem cannot start.
  Future<String?> exportIncident(Map<String, Object?> incident) async {
    await ErrorLogService.instance.initialize();
    final text = DiagnosticRedactor.text(
      'Vigia IA - Diagnóstico automático\n'
      'Exportador: ${AppMetadata.version}+${AppMetadata.build}\n'
      'Gerado em: ${DateTime.now().toIso8601String()}\n'
      'Sessão anterior preservada; a versão da falha consta no registro abaixo.\n'
      '=== INCIDENTE E HISTÓRICO ANTERIOR ===\n'
      '${const JsonEncoder.withIndent('  ').convert(incident)}\n'
      '=== ERROS GERAIS PERSISTIDOS (podem incluir outras sessões) ===\n'
      '${ErrorLogService.instance.exportText()}\n',
    );
    return NativePlatformService.instance.saveBytesToDownloads(
      fileName: 'vigiaia_falha_${DateTime.now().millisecondsSinceEpoch}.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
  }

  @visibleForTesting
  void stop() {
    _timer?.cancel();
    _started = false;
    ErrorLogService.instance.onRecorded = null;
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    WidgetsBinding.instance.removeObserver(this);
  }
}
