import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/rgb_frame.dart';
import '../services/error_log_service.dart';
import '../services/frame_converter.dart';
import '../services/rtsp_diagnostics_service.dart';
import '../services/minha_camera_live_url.dart';
import '../services/rtsp_recovery_policy.dart';
import '../services/rtsp_frame_watchdog_policy.dart';

/// Fonte VLC para monitoramento (inclusive captura de quadros para a IA).
/// Media3 continua isolado na tela de teste, sem concorrer com este player.
class RtspCameraSource implements VideoSource {
  RtspCameraSource({
    required this.url,
    required this.analysisInterval,
    this.emitFrames = true,
    this.softwareDecoding = false,
    this.forceTcp = true,
    this.rawH264 = false,
  });

  final String url;
  final Duration analysisInterval;
  final bool emitFrames;
  final bool softwareDecoding;
  final bool forceTcp;
  /// HTTP com vídeo AVC Annex-B (não é RTSP), validado pelo QR local.
  final bool rawH264;
  final _frames = StreamController<RgbFrame>.broadcast();
  final _statuses = StreamController<VideoSourceStatus>.broadcast();
  final ErrorLogService _logs = ErrorLogService.instance;
  final RtspDiagnosticsService _diagnostics = RtspDiagnosticsService.instance;
  final RtspRecoveryPolicy _recovery = RtspRecoveryPolicy();
  final RtspFrameWatchdogPolicy _healthPolicy = const RtspFrameWatchdogPolicy();

  VlcPlayerController? _controller;
  Timer? _snapshotTimer;
  Timer? _watchdog;
  Timer? _reconnectTimer;
  bool _snapshotInFlight = false;
  bool _reconnecting = false;
  bool _disposed = false;
  bool _previewLogged = false;
  bool _playingLogged = false;
  bool _bufferingLogged = false;
  bool _frameConfirmed = false;
  bool _recoveryExhaustionLogged = false;
  bool _snapshotWarningLogged = false;
  String? _lastPlayerError;
  DateTime? _attachedAt;
  DateTime? _lastSnapshotProbe;
  DateTime _lastSuccessfulFrame = DateTime.fromMillisecondsSinceEpoch(0);

  VlcPlayerController? get controller => _controller;

  @override
  Stream<RgbFrame> get frames => _frames.stream;

  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  VlcMediaSource get _mediaSource => VlcMediaSource(
        uri: Uri.parse(url),
        mediaOptions: <String>[
          if (rawH264) ':network-caching=220' else ':network-caching=500',
          if (rawH264) ':demux=h264',
          if (!rawH264 && forceTcp) ':rtsp-tcp',
          ':no-audio',
          if (softwareDecoding) ...<String>[
            ':avcodec-hw=none',
            ':no-mediacodec',
            ':no-omxil',
          ],
        ],
      );

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('Fonte RTSP ja descartada.');
    final uri = Uri.tryParse(url);
    if (uri == null || (rawH264
        ? !MinhaCameraLiveUrl.isValidH264(url)
        : uri.scheme.toLowerCase() != 'rtsp' || uri.host.isEmpty)) {
      throw const FormatException('Endereco do fluxo de video invalido.');
    }
    if (_controller != null) return;

    await _diagnostics.mark('source_start', address: url);
    await _logs.record(
      level: ErrorLogLevel.info,
      source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
      message: 'Fonte VLC iniciada; aguardando player e primeiro quadro.',
      context: <String, Object?>{
        'host': RtspDiagnosticsService.safeHost(url),
        'engine': 'LibVLC',
        'transport': rawH264 ? 'HTTP Annex-B' : (forceTcp ? 'TCP' : 'VLC padrao'),
        'softwareDecoding': softwareDecoding,
      },
    );
    if (_disposed) return;

    _statuses.add(const VideoSourceStatus(
      VideoSourceState.connecting,
      message: 'Conectando ao stream RTSP...',
    ));

    final controller = VlcPlayerController(
      mediaSource: _mediaSource,
      autoPlay: true,
      options: const <String>['--no-audio'],
      eventThrottleInterval: const Duration(milliseconds: 250),
    );
    _controller = controller;
    await _diagnostics.mark('controller_created', address: url);
    if (_disposed || _controller != controller) return;
    controller.addListener(_onPlayerChanged);

    // O prazo de abertura so comeca quando a view nativa estiver anexada.
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkPlayback();
    });
    if (emitFrames) {
      _snapshotTimer = Timer.periodic(analysisInterval, (_) {
        unawaited(_captureSnapshot());
      });
    }
  }

  void _onPlayerChanged() {
    if (_disposed || _controller == null || _statuses.isClosed) return;
    final value = _controller!.value;
    if (value.hasError) {
      if (_recovery.exhausted && _recoveryExhaustionLogged) return;
      final message = value.errorDescription ?? 'Falha no stream RTSP.';
      if (_lastPlayerError != message) {
        _lastPlayerError = message;
        unawaited(_diagnostics.mark('player_error', address: url));
        unawaited(_logs.record(
          level: ErrorLogLevel.error,
          source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
          message: 'O player VLC reportou falha na transmissão.',
          // Erros nativos podem conter URL com senha: não exportar details.
          context: <String, Object?>{
            'host': RtspDiagnosticsService.safeHost(url),
            'engine': 'LibVLC',
            'transport': rawH264 ? 'HTTP Annex-B' : (forceTcp ? 'TCP' : 'VLC padrao'),
          },
        ));
      }
      _statuses.add(const VideoSourceStatus(
        VideoSourceState.error,
        message: 'Falha na reprodução RTSP. Tentando recuperar...',
      ));
      _scheduleReconnect('player_error');
      return;
    }
    if (value.isPlaying) {
      if (!_playingLogged) {
        _playingLogged = true;
        unawaited(_diagnostics.mark('playing', address: url));
        unawaited(_logs.record(
          level: ErrorLogLevel.info,
          source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
          message: 'VLC iniciou a reprodução (quadro ainda não confirmado).',
          context: <String, Object?>{'host': RtspDiagnosticsService.safeHost(url)},
        ));
      }
      if (_frameConfirmed) {
        _statuses.add(const VideoSourceStatus(VideoSourceState.streaming));
      } else {
        _statuses.add(const VideoSourceStatus(VideoSourceState.connecting,
          message: 'VLC conectado; aguardando quadro de vídeo…'));
      }
    } else if (value.isBuffering) {
      if (!_bufferingLogged) {
        _bufferingLogged = true;
        unawaited(_diagnostics.mark('buffering', address: url));
      }
      _statuses.add(const VideoSourceStatus(
        VideoSourceState.connecting,
        message: 'Bufferizando stream RTSP...',
      ));
    }
  }

  void _checkPlayback() {
    final controller = _controller;
    if (_disposed || controller == null || !controller.isAttached) return;
    final now = DateTime.now();
    _attachedAt ??= now;
    if (_reconnectTimer != null || _reconnecting) return;
    if (!emitFrames && controller.value.isPlaying && !_snapshotInFlight &&
        (_lastSnapshotProbe == null ||
         now.difference(_lastSnapshotProbe!) >= const Duration(seconds: 4))) {
      // Sem IA, sondar periodicamente sem conversao RGB para detectar
      // congelamento; nao ficar apenas no primeiro quadro da transmissao.
      _lastSnapshotProbe = now;
      unawaited(_captureSnapshot());
    }
    // isPlaying nao confirma um quadro novo. Sem IA, o snapshot e sondado
    // a cada 4 s, e com IA ele segue a cadencia configurada.
    final issue = _healthPolicy.check(
      now: now,
      attachedAt: _attachedAt!,
      lastSuccessfulSnapshot: _frameConfirmed ? _lastSuccessfulFrame : null,
    );
    if (issue == RtspFrameIssue.firstFrameTimeout) {
      _scheduleReconnect('first_frame_timeout');
    } else if (issue == RtspFrameIssue.possibleFrameStall) {
      _scheduleReconnect('possible_frame_stall');
    }
  }

  Future<void> _captureSnapshot() async {
    if (_snapshotInFlight || _disposed || _reconnecting) return;
    final controller = _controller;
    if (controller == null || !controller.isAttached || !controller.value.isPlaying) return;

    _snapshotInFlight = true;
    try {
      final bytes = await controller.takeSnapshot(width: 640)
          .timeout(const Duration(seconds: 6));
      if (bytes.isEmpty) throw StateError('Snapshot RTSP vazio.');
      // Somente decodificar em RGB quando necessário para IA, evitando CPU
      // extra no modo de prévia da câmera secundária.
      RgbFrame? frame;
      if (emitFrames) {
        frame = await FrameConverter.fromEncoded(bytes, capturedAt: DateTime.now());
      }
      if (_disposed || _controller != controller) return;
      _lastSuccessfulFrame = DateTime.now();
      if (!_frameConfirmed) {
        _frameConfirmed = true;
        unawaited(_diagnostics.mark('first_frame', address: url));
        unawaited(_logs.record(
          level: ErrorLogLevel.info,
          source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
          message: 'Primeiro quadro RTSP confirmado por snapshot VLC.',
          context: <String, Object?>{
            'host': RtspDiagnosticsService.safeHost(url),
            'engine': 'LibVLC',
            'transport': rawH264 ? 'HTTP Annex-B' : (forceTcp ? 'TCP' : 'VLC padrao'),
          },
        ));
      }
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      if (!_statuses.isClosed) {
        _statuses.add(const VideoSourceStatus(VideoSourceState.streaming));
      }
      _recovery.confirmedFrame();
      _recoveryExhaustionLogged = false;
      _snapshotWarningLogged = false;
      if (frame != null && !_frames.isClosed) _frames.add(frame);
    } catch (_) {
      if (!_snapshotWarningLogged) {
        _snapshotWarningLogged = true;
        unawaited(_logs.record(
          level: ErrorLogLevel.warning,
          source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
          message: 'Snapshot do VLC indisponível; reprodução pode continuar.',
          context: <String, Object?>{'host': RtspDiagnosticsService.safeHost(url)},
        ));
      }
      // Falha de captura isolada não prova falha do transporte ou do decoder.
    } finally {
      _snapshotInFlight = false;
    }
  }

  void _scheduleReconnect(String reason) {
    final controller = _controller;
    if (_disposed || controller == null || !controller.isAttached ||
        _reconnectTimer != null || _reconnecting ||
        (_recovery.exhausted && _recoveryExhaustionLogged)) return;
    final delay = _recovery.scheduleNext();
    if (delay == null) {
      if (!_recoveryExhaustionLogged) {
        _recoveryExhaustionLogged = true;
        unawaited(_diagnostics.mark('recovery_exhausted', address: url));
        unawaited(_logs.record(
          level: ErrorLogLevel.warning,
          source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
          message: 'Limite de 3 reconexões atingido; reabra a câmera para tentar novamente.',
          context: <String, Object?>{'host': RtspDiagnosticsService.safeHost(url)},
        ));
      }
      if (!_statuses.isClosed) {
        _statuses.add(const VideoSourceStatus(
          VideoSourceState.error,
          message: 'RTSP indisponível após 3 tentativas. Reabra a câmera.',
        ));
      }
      return;
    }
    final attempt = _recovery.attempts;
    _statuses.add(VideoSourceStatus(
      VideoSourceState.reconnecting,
      message: 'Reconectando RTSP ($attempt/3)...',
    ));
    unawaited(_diagnostics.mark('reconnect_scheduled', address: url));
    unawaited(_logs.record(
      level: ErrorLogLevel.info,
      source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
      message: 'Reconexão RTSP agendada.',
      context: <String, Object?>{
        'host': RtspDiagnosticsService.safeHost(url),
        'attempt': attempt,
        'delaySeconds': delay.inSeconds,
        'reason': reason,
      },
    ));
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_reconnect());
    });
  }

  Future<void> _reconnect() async {
    final controller = _controller;
    if (_disposed || controller == null || !controller.isAttached || _reconnecting) return;
    _reconnecting = true;
    _playingLogged = false;
    _bufferingLogged = false;
    _lastPlayerError = null;
    _frameConfirmed = false;
    _attachedAt = DateTime.now();
    _lastSnapshotProbe = null;
    try {
      await controller.setMedia(_mediaSource, autoPlay: true);
      if (!_disposed && _controller == controller) {
        unawaited(_diagnostics.mark('reconnect_sent', address: url));
      }
    } catch (_) {
      if (!_disposed && _controller == controller) {
        unawaited(_logs.record(
          level: ErrorLogLevel.error,
          source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
          message: 'Falha ao reiniciar a transmissão RTSP.',
          context: <String, Object?>{'host': RtspDiagnosticsService.safeHost(url)},
        ));
      }
    } finally {
      _reconnecting = false;
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_previewLogged) {
      _previewLogged = true;
      unawaited(_diagnostics.mark('preview_requested', address: url));
    }
    return VlcPlayer(controller: controller, fit: VlcVideoFit.contain);
  }

  @override
  Future<void> stop() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final controller = _controller;
    _controller = null;
    await _diagnostics.mark('stopped', address: url);
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      try {
        if (controller.isAttached) await controller.stop();
      } catch (_) {
        unawaited(_logs.record(
          level: ErrorLogLevel.warning,
          source: rawH264 ? 'Minha Câmera H.264' : 'RTSP',
          message: 'Aviso ao interromper o stream RTSP.',
          context: <String, Object?>{'host': RtspDiagnosticsService.safeHost(url)},
        ));
      }
      controller.dispose();
    }
    if (!_statuses.isClosed) {
      _statuses.add(const VideoSourceStatus(VideoSourceState.stopped));
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _frames.close();
    await _statuses.close();
  }
}
