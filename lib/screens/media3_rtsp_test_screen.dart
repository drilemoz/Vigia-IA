import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/error_log_service.dart';
import '../services/automatic_diagnostics_service.dart';
import '../services/rtsp_diagnostics_service.dart';

/// Primeira etapa da migração RTSP: reproduz vídeo nativo via Media3, SEM IA.
/// O LibVLC do modo Monitorar e o receptor MCRP continuam independentes.
class Media3RtspTestScreen extends StatefulWidget {
  const Media3RtspTestScreen({
    super.key,
    required this.cameraName,
    required this.url,
    required this.forceTcp,
  });

  final String cameraName;
  final String url;
  final bool forceTcp;

  @override
  State<Media3RtspTestScreen> createState() => _Media3RtspTestScreenState();
}

class _Media3RtspTestScreenState extends State<Media3RtspTestScreen> {
  final _diagnostics = RtspDiagnosticsService.instance;
  final _logs = ErrorLogService.instance;
  DateTime _startedAt = DateTime.now();
  MethodChannel? _channel;
  Timer? _elapsedTimer;
  String _phase = 'connecting';
  String? _errorCode;
  String? _lastLoggedError;
  bool _firstFrame = false;
  bool _timedOut = false;
  bool _loggedFirstFrame = false;
  int _width = 0;
  int _height = 0;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    AutomaticDiagnosticsService.instance.recordUiAction('media3', 'abrir_previa');
    unawaited(_diagnostics.mark('open_requested', address: widget.url));
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _firstFrame) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
        // Timeout é aviso diagnóstico, não prova falha nem fecha o player.
        if (_elapsedSeconds >= 20) _timedOut = true;
      });
    });
  }

  Future<void> _onPlatformViewCreated(int id) async {
    final channel = MethodChannel('vigiaia/media3_rtsp/$id');
    _channel = channel;
    AutomaticDiagnosticsService.instance.recordUiAction('media3', 'view_criada');
    unawaited(_diagnostics.mark('controller_created', address: widget.url));
    channel.setMethodCallHandler((call) async {
      if (call.method == 'state' && call.arguments is Map) {
        _receiveStatus(call.arguments as Map<Object?, Object?>);
      }
    });
    try {
      final result = await channel.invokeMapMethod<Object?, Object?>('getStatus');
      if (result != null) _receiveStatus(result);
    } on PlatformException {
      if (mounted) setState(() { _phase = 'error'; _errorCode = 'CANAL_NATIVO'; });
    } on MissingPluginException {
      if (mounted) setState(() { _phase = 'error'; _errorCode = 'MEDIA3_INDISPONIVEL'; });
    }
  }

  void _receiveStatus(Map<Object?, Object?> value) {
    if (!mounted) return;
    final phase = value['state'];
    if (phase is String && phase != _phase) {
      const permitted = {'connecting', 'buffering', 'ready', 'ended', 'error', 'paused'};
      AutomaticDiagnosticsService.instance.recordUiAction(
        'media3_estado', permitted.contains(phase) ? phase : 'desconhecido');
      if (phase == 'buffering') {
        unawaited(_diagnostics.mark('buffering', address: widget.url));
      }
    }
    final code = value['errorCode'];
    final firstFrame = value['firstFrame'] == true;
    setState(() {
      _phase = phase is String ? phase : 'connecting';
      _firstFrame = firstFrame;
      _errorCode = code is String ? code : null;
      _width = value['width'] is int ? value['width'] as int : 0;
      _height = value['height'] is int ? value['height'] as int : 0;
      if (firstFrame) _timedOut = false;
    });
    if (firstFrame && !_loggedFirstFrame) {
      _loggedFirstFrame = true;
      unawaited(_diagnostics.mark('playing', address: widget.url));
      unawaited(_logs.record(
        level: ErrorLogLevel.info,
        source: 'RTSP Media3',
        message: 'Primeiro frame renderizado pelo Media3 RTSP.',
        context: <String, Object?>{
          'host': RtspDiagnosticsService.safeHost(widget.url),
          'transport': widget.forceTcp ? 'TCP' : 'UDP/TCP',
          'width': _width,
          'height': _height,
        },
      ));
    }
    if (_phase == 'error' && _lastLoggedError != _errorCode) {
      _lastLoggedError = _errorCode;
      unawaited(_diagnostics.mark('player_error', address: widget.url));
      unawaited(_logs.record(
        level: ErrorLogLevel.warning,
        source: 'RTSP Media3',
        message: 'Falha na reprodução da prévia RTSP Media3.',
        context: <String, Object?>{
          'host': RtspDiagnosticsService.safeHost(widget.url),
          'errorCode': _errorCode ?? 'DESCONHECIDO',
          'firstFrame': _firstFrame,
        },
      ));
    }
  }

  Future<void> _retry() async {
    final channel = _channel;
    if (channel == null) return;
    AutomaticDiagnosticsService.instance.recordUiAction('media3', 'tentar_novamente');
    _startedAt = DateTime.now();
    setState(() {
      _phase = 'connecting';
      _errorCode = null;
      _lastLoggedError = null;
      _timedOut = false;
      _firstFrame = false;
      _loggedFirstFrame = false;
      _elapsedSeconds = 0;
    });
    try {
      final result = await channel.invokeMapMethod<Object?, Object?>('retry');
      if (result != null) _receiveStatus(result);
    } on PlatformException {
      if (mounted) setState(() { _phase = 'error'; _errorCode = 'REINICIO_FALHOU'; });
    }
  }

  String get _description {
    if (_phase == 'error') {
      return 'Reprodução interrompida: ${_errorCode ?? 'DESCONHECIDA'}'
          '${_firstFrame ? ' (imagem chegou antes da falha)' : ''}';
    }
    if (_firstFrame) {
      return _width > 0 && _height > 0
          ? 'Imagem confirmada: $_width × $_height · Media3'
          : 'Primeiro frame confirmado pelo Media3';
    }
    if (_phase == 'ended') return 'A transmissão terminou antes da confirmação de imagem.';
    if (_timedOut) return 'Sem primeiro frame após 20 s. Confira o codec, o caminho e a rede.';
    if (_phase == 'ready') return 'Player preparado; aguardando o primeiro frame…';
    if (_phase == 'buffering') return 'Recebendo e preparando o vídeo RTSP…';
    return 'Conectando à câmera RTSP… ($_elapsedSeconds s)';
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _channel?.setMethodCallHandler(null);
    // AndroidView.dispose() libera o ExoPlayer nativo; não reusar no Monitorar.
    unawaited(_diagnostics.mark('stopped', address: widget.url));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uri = Uri.tryParse(widget.url);
    return Scaffold(
      appBar: AppBar(title: const Text('Teste RTSP · Media3')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.cameraName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${uri?.host ?? 'Câmera RTSP'} · ${widget.forceTcp ? 'TCP' : 'UDP com fallback TCP'} · sem IA',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AndroidView(
                        viewType: 'vigiaia/media3_rtsp',
                        creationParams: <String, Object>{
                          'url': widget.url,
                          'forceTcp': widget.forceTcp,
                        },
                        creationParamsCodec: const StandardMessageCodec(),
                        onPlatformViewCreated: (id) => unawaited(_onPlatformViewCreated(id)),
                      ),
                      if (!_firstFrame && _phase != 'error' && _phase != 'ended' && !_timedOut)
                        const IgnorePointer(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _phase == 'error' ? Icons.error_outline
                      : _firstFrame ? Icons.check_circle_outline : Icons.info_outline,
                  color: _phase == 'error' ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_description)),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _channel == null ? null : _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
            const SizedBox(height: 10),
            Text(
              'Teste experimental de reprodução H.264. Não ativa monitoramento, IA, gravação ou transmissão. '
              'O botão Monitorar ainda utiliza o VLC nesta versão. '
              'Se houver vídeo aqui e falha no monitoramento, a diferença entre os motores poderá ser investigada.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
