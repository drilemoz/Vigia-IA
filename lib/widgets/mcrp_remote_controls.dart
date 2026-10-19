import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mcrp_client.dart';

/// Telemetria compartilhada com a prévia, atualizada SOMENTE pela consulta
/// MCRP já existente. Nunca cria um segundo polling de rede/CPU.
class McrpLiveStatusCache {
  static final ValueNotifier<Map<String, String>> status =
      ValueNotifier<Map<String, String>>(const <String, String>{});
  static String? liveUrl;
  static void setStatus(String url, Map<String, String> data) {
    liveUrl = url;
    status.value = Map<String, String>.unmodifiable(data);
  }
  static void clear(String url) {
    if (liveUrl == url) {
      liveUrl = null;
      status.value = const <String, String>{};
    }
  }
  /// A conexão de vídeo não é autoridade sobre REC: o serviço MCRP é.
  /// Estado desconhecido nunca deve ser representado como AO VIVO ou PAUSADO.
  static bool get isUnavailable => status.value['x-link-unavailable'] == '1';
  static bool get isPaused => status.value['x-transmitting'] == '0';
  static bool get isLive => status.value['x-transmitting'] == '1';

  static String duration(String? raw) {
    final seconds = (int.tryParse(raw ?? '') ?? 0).clamp(0, 315360000);
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds ~/ 60) % 60).toString().padLeft(2, '0');
    final secondPart = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secondPart';
  }
}

/// Controles MCRP para o receptor. Não cria uma segunda conexão de vídeo,
/// apenas consulta /status e envia POSTs autenticados ao transmissor.
class McrpControlPanel extends StatelessWidget {
  const McrpControlPanel({
    super.key,
    required this.status,
    required this.working,
    required this.onCommand,
    this.onReconnect,
    this.onMedia,
    this.onDiagnostic,
    this.allowCodecChange = false,
    this.compact = false,
  });

  final Map<String, String> status;
  final bool working;
  final Future<void> Function(String action) onCommand;
  final VoidCallback? onReconnect;
  final VoidCallback? onMedia;
  final VoidCallback? onDiagnostic;
  final bool allowCodecChange;
  final bool compact;

  bool get _transmitting => status['x-transmitting'] != '0';
  bool get _transmittingKnown => status['x-transmitting'] == '0' || status['x-transmitting'] == '1';
  bool get _recording => status['x-recording'] == '1';
  bool get _recordingKnown => status['x-recording'] == '0' || status['x-recording'] == '1';
  bool get _eco => status['x-eco'] == '1';
  bool get _torchSupported => status['x-torch-supported'] == '1';
  bool get _torchEnabled => status['x-torch-enabled'] == '1';
  bool get _zoomSupported => status['x-zoom-supported'] == '1';
  int get _zoom => (int.tryParse(status['x-zoom-percent'] ?? '') ?? 0).clamp(0, 100).toInt();
  String get _codec => status['x-stream-codec'] ?? 'mjpeg';

  Widget _action(BuildContext context, IconData icon, String label,
      VoidCallback? onPressed, {bool selected = false, String? statusText}) {
    final theme = Theme.of(context);
    return SizedBox(
      height: compact ? 58 : 72,
      child: OutlinedButton(
        onPressed: working ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLowest,
          foregroundColor: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (statusText != null)
            Text(statusText, style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.w700,
              color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant)),
          Icon(icon, size: statusText != null && compact ? 17 : compact ? 20 : 24,
            color: working || onPressed == null ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                : selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.w700,
              color: working || onPressed == null ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                : selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 420 ? 5 : 4;
        const gap = 7.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final actions = <Widget>[
          if (_transmittingKnown)
            _action(context, _transmitting ? Icons.pause_circle_outline : Icons.play_circle_outline,
              _transmitting ? 'Pausar' : 'Iniciar',
              !_recording ? () => onCommand(_transmitting ? 'transmission/stop' : 'transmission/start') : null,
              selected: !_transmitting),
          if (_transmitting) _action(context, _recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
            _recording ? 'Parar REC' : 'Iniciar REC',
            _recordingKnown ? () => onCommand(_recording ? 'record/stop' : 'record/start') : null,
            selected: _recording),
          if (_transmitting) _action(context, Icons.photo_camera_outlined, 'Foto', () => onCommand('photo')),
          if (_transmitting) _action(context, Icons.cameraswitch_outlined, 'Câmera', () => onCommand(
            status['x-camera-facing'] == '1' ? 'camera/back' : 'camera/front')),
          if (_transmitting) _action(context, Icons.battery_saver_outlined, 'Eco', () => onCommand(
            _eco ? 'eco/disable' : 'eco/enable'), selected: _eco),
          if (_transmitting) _action(context, _torchEnabled ? Icons.flash_on : Icons.flash_off, 'Lanterna',
            _torchSupported ? () => _openTorchDialog(context) : null,
            selected: _torchEnabled,
            statusText: _torchEnabled ? 'Ativada' : 'Desativada'),
          if (_transmitting) _action(context, Icons.zoom_in_map_outlined, 'Zoom',
            _zoomSupported ? () => _openZoomDialog(context) : null),
          if (_transmitting) _action(context, Icons.high_quality_outlined, 'Vídeo',
            () => _openVideoDialog(context)),
          if (onMedia != null)
            _action(context, Icons.video_library_outlined, 'Mídias', onMedia),
          if (onDiagnostic != null)
            _action(context, Icons.bug_report_outlined, 'Diagnóstico', onDiagnostic),
        ];
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final action in actions) SizedBox(width: width, child: action),
        ]);
      }),
      const SizedBox(height: 10),
      if (_transmitting && allowCodecChange)
        _setting(context, 'Codec', _codec.toUpperCase(),
          const <String, String>{'MJPEG': 'codec/mjpeg', 'H.264': 'codec/h264'}),
    ]);
  }


  Future<void> _openZoomDialog(BuildContext context) async {
    var zoom = _zoom;
    var sending = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          Future<void> adjust(int next) async {
            if (sending || working) return;
            final target = next.clamp(0, 100).toInt();
            if (target == zoom) return;
            update(() => sending = true);
            try {
              await onCommand('zoom/$target');
              if (dialogContext.mounted) update(() => zoom = target);
            } finally {
              if (dialogContext.mounted) update(() => sending = false);
            }
          }
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Material(
                color: Theme.of(dialogContext).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Expanded(child: Text('Zoom',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                    Row(children: [
                      Text('$zoom%', style: Theme.of(dialogContext).textTheme.titleLarge),
                      const Spacer(),
                      IconButton.filledTonal(
                        tooltip: 'Diminuir zoom',
                        onPressed: !sending && zoom > 0 ? () => unawaited(adjust(zoom - 10)) : null,
                        icon: const Icon(Icons.zoom_out),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Aumentar zoom',
                        onPressed: !sending && zoom < 100 ? () => unawaited(adjust(zoom + 10)) : null,
                        icon: const Icon(Icons.zoom_in),
                      ),
                      IconButton.outlined(
                        tooltip: 'Zoom original (1×)',
                        onPressed: !sending && zoom > 0 ? () => unawaited(adjust(0)) : null,
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openTorchDialog(BuildContext context) async {
    final choices = <String, String>{
      'Desligar': 'torch/off',
      'Ligar por 30 segundos': 'torch/30',
      'Ligar por 120 segundos': 'torch/120',
      'Ligar durante gravação': 'torch/record',
    };
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Lanterna do transmissor'),
        children: [
          for (final entry in choices.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(entry.value),
              child: Row(children: [
                Icon((status['x-torch-mode'] == entry.value.substring(6))
                  ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                const SizedBox(width: 10),
                Expanded(child: Text(entry.key)),
              ]),
            ),
        ],
      ),
    );
    if (selected != null && context.mounted) await onCommand(selected);
  }

  Future<void> _openVideoDialog(BuildContext context) async {
    const resolutions = <String, String>{
      '360p': 'quality/360', '480p': 'quality/480',
      '720p': 'quality/720', '768p': 'quality/768', '1080p': 'quality/1080',
    };
    const frameRates = <String, String>{
      '5 FPS': 'fps/5', '10 FPS': 'fps/10', '15 FPS': 'fps/15',
      '24 FPS': 'fps/24', '30 FPS': 'fps/30',
    };
    var selectedResolution = status['x-quality-profile'] ?? '';
    var selectedFps = status['x-fps-target'] ?? '';
    var sending = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          Future<void> send(String action, {required bool quality}) async {
            if (sending || working) return;
            update(() => sending = true);
            try {
              await onCommand(action);
              if (dialogContext.mounted) {
                update(() {
                  if (quality) { selectedResolution = action.substring(8); }
                  else { selectedFps = action.substring(4); }
                });
              }
            } finally {
              if (dialogContext.mounted) update(() => sending = false);
            }
          }
          return AlertDialog(
            title: const Text('Resolução e FPS'),
            content: SizedBox(
              width: 440,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Resolução', style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final entry in resolutions.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      enabled: !sending,
                      leading: Icon(selectedResolution == entry.value.substring(8)
                          ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                      title: Text(entry.key, style: const TextStyle(fontSize: 12)),
                      onTap: () => unawaited(send(entry.value, quality: true)),
                    ),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('FPS', style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final entry in frameRates.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      enabled: !sending,
                      leading: Icon(selectedFps == entry.value.substring(4)
                          ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                      title: Text(entry.key, style: const TextStyle(fontSize: 12)),
                      onTap: () => unawaited(send(entry.value, quality: false)),
                    ),
                ])),
              ]),
            ),
            actions: [TextButton(
              onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            )],
          );
        },
      ),
    );
  }

  Widget _setting(BuildContext context, String label, String? current,
      Map<String, String> options) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Alterar $label no Redmi A3',
      enabled: !working,
      onSelected: (action) => unawaited(onCommand(action)),
      itemBuilder: (_) => [
        for (final entry in options.entries)
          PopupMenuItem<String>(value: entry.value, child: Text(entry.key)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label${current == null ? '' : ': $current'}', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 17),
        ]),
      ),
    );
  }
}

/// Ao Vivo: consulta/controle MCRP opcional, exclusivo para URLs /live/ privadas.
/// A prévia e a IA continuam sob responsabilidade do MonitorController.
class McrpLiveRemoteControls extends StatefulWidget {
  const McrpLiveRemoteControls({
    super.key, required this.liveUrl,
    this.onTogglePartialPerson, this.partialPersonEnabled = false,
  });
  final String liveUrl;
  final VoidCallback? onTogglePartialPerson;
  final bool partialPersonEnabled;

  @override
  State<McrpLiveRemoteControls> createState() => _McrpLiveRemoteControlsState();
}

class _McrpLiveRemoteControlsState extends State<McrpLiveRemoteControls>
    with WidgetsBindingObserver {
  McrpClient? _client;
  Timer? _poll;
  Map<String, String> _status = const {};
  bool _busy = false;
  bool _polling = false;
  bool _ready = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void didUpdateWidget(covariant McrpLiveRemoteControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liveUrl != oldWidget.liveUrl) {
      McrpLiveStatusCache.clear(oldWidget.liveUrl);
      _connect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_refresh());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _poll?.cancel();
    }
  }

  void _connect() {
    final generation = ++_generation;
    _poll?.cancel();
    McrpLiveStatusCache.clear(widget.liveUrl);
    _client?.close();
    _status = const {};
    _ready = false;
    _busy = false;
    _polling = false;
    _error = null;
    try {
      _client = McrpClient(McrpAddress.parse(widget.liveUrl));
      _startPolling();
      unawaited(_refresh(generation: generation));
    } catch (_) {
      _client = null;
      _error = 'Endereço MCRP não reconhecido.';
    }
  }

  void _startPolling() {
    _poll?.cancel();
    if (_client != null) {
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => unawaited(_refresh()));
    }
  }

  Future<void> _refresh({int? generation}) async {
    if (_polling || _busy) return;
    final client = _client;
    if (client == null) return;
    final current = generation ?? _generation;
    _polling = true;
    try {
      final status = await client.status();
      if (!mounted || current != _generation || client != _client) return;
      McrpLiveStatusCache.setStatus(widget.liveUrl, status);
      setState(() { _status = status; _ready = true; _error = null; });
    } catch (_) {
      if (mounted && current == _generation && client == _client) {
        // Sem status atualizado não manter um selo AO VIVO nem tempo de REC
        // de uma consulta antiga. A gravação no transmissor não é interrompida.
        McrpLiveStatusCache.setStatus(widget.liveUrl,
            const <String, String>{'x-link-unavailable': '1'});
        setState(() { _ready = false; _error = 'Sem comunicação com o transmissor. Uma gravação já iniciada pode continuar no aparelho.'; });
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _command(String action) async {
    final client = _client;
    if (client == null || _busy || !_ready) return;
    final generation = _generation;
    final recordingCommand = action == 'record/start' || action == 'record/stop';
    final transmissionCommand = action == 'transmission/start' || action == 'transmission/stop';
    final expectedTransmission = action == 'transmission/start' ? '1' : '0';
    final expectedRecording = action == 'record/start' ? '1' : '0';
    setState(() { _busy = true; _error = null; });
    var sent = false;
    try {
      await client.command(action);
      sent = true;
      // Confirma o estado real no transmissor. Não envia o POST de novo
      // quando um pacote de resposta ou a conexão se perde.
      for (var attempt = 0; attempt < (transmissionCommand ? 12 : recordingCommand ? 5 : 1); attempt++) {
        if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 450));
        final state = await client.status();
        if (!mounted || _generation != generation || client != _client) return;
        McrpLiveStatusCache.setStatus(widget.liveUrl, state);
        setState(() { _status = state; _ready = true; _error = null; });
        if (transmissionCommand && state['x-transmitting'] == expectedTransmission) return;
        if (!transmissionCommand && (!recordingCommand || state['x-recording'] == expectedRecording)) return;
      }
      if (mounted && _generation == generation && client == _client) {
        setState(() => _error = transmissionCommand
            ? 'Comando enviado; aguardando confirmação da transmissão.'
            : 'Comando enviado, aguardando confirmação do estado REC.');
      }
    } catch (error) {
      if (mounted && _generation == generation && client == _client) {
        setState(() {
          if (sent) {
            _ready = false;
            McrpLiveStatusCache.setStatus(widget.liveUrl,
                const <String, String>{'x-link-unavailable': '1'});
          }
          _error = sent
            ? 'Comando enviado, mas não foi possível confirmar o estado. Reconecte para consultar.'
            : error is StateError ? error.message.toString()
            : 'O transmissor não confirmou o comando. Verifique a rede.';
        });
      }
    } finally {
      if (mounted && _generation == generation && client == _client) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _poll?.cancel();
    McrpLiveStatusCache.clear(widget.liveUrl);
    _client?.close();
    super.dispose();
  }

  void _showControlHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajuda do controle remoto'),
        content: const SingleChildScrollView(child: Text(
          'Parar transmissão libera câmera e encoder; o serviço mantém a escuta local. '
          'Iniciar vídeo requer que o serviço esteja ativo e o Android permita reabrir a câmera. '
          'Iniciar/Parar REC grava no celular transmissor. Uma gravação ativa '
          'não depende da conexão com o receptor. Para enviar novos comandos, '
          'os aparelhos precisam estar conectados na rede local.',
        )),
        actions: [TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Entendi'),
        )],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.settings_remote_outlined, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Controle remoto · ${_status['x-device-model']?.trim().isNotEmpty == true ? _status['x-device-model'] : 'Vigia IA'}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800))),
            if (widget.onTogglePartialPerson != null)
              IconButton(
                iconSize: 21,
                visualDensity: VisualDensity.compact,
                tooltip: widget.partialPersonEnabled
                    ? 'Desligar possível pessoa (experimental)'
                    : 'Ligar possível pessoa (experimental)',
                onPressed: widget.onTogglePartialPerson,
                icon: Icon(Icons.face_outlined,
                  color: widget.partialPersonEnabled ? Colors.blue : scheme.onSurfaceVariant),
              ),
            IconButton(
              iconSize: 19,
              visualDensity: VisualDensity.compact,
              tooltip: 'Ajuda dos controles da câmera',
              onPressed: () => _showControlHelp(context),
              icon: Icon(Icons.help_outline, color: scheme.onSurface),
            ),
            Icon(_ready ? Icons.wifi : Icons.wifi_off,
              size: 26, color: _ready ? scheme.primary : scheme.error),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 7),
            Text(_error!, style: TextStyle(fontSize: 12, color: scheme.error)),
          ],
          const SizedBox(height: 9),
          if (!_ready)
            OutlinedButton.icon(onPressed: _busy ? null : () => unawaited(_refresh()),
              icon: const Icon(Icons.refresh), label: const Text('Conectar controles'))
          else
            McrpControlPanel(status: _status, working: _busy,
              compact: true, onCommand: _command),
        ]),
      ),
    );
  }
}
