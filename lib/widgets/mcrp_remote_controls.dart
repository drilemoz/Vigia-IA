import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mcrp_client.dart';

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
      VoidCallback? onPressed, {bool selected = false}) {
    final theme = Theme.of(context);
    return SizedBox(
      height: compact ? 58 : 72,
      child: OutlinedButton(
        onPressed: working ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          foregroundColor: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: compact ? 20 : 24),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 420 ? 5 : 4;
        const gap = 7.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final actions = <Widget>[
          if (_transmittingKnown)
            _action(context, _transmitting ? Icons.pause_circle_outline : Icons.play_circle_outline,
              _transmitting ? 'Parar transmissão' : 'Iniciar transmissão',
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
            _torchSupported ? () => onCommand(_torchEnabled ? 'torch/off' : 'torch/30') : null,
            selected: _torchEnabled),
          if (_transmitting) _action(context, Icons.zoom_out, 'Zoom −',
            _zoomSupported && _zoom > 0 ? () => onCommand('zoom/${(_zoom - 10).clamp(0, 100)}') : null),
          if (_transmitting) _action(context, Icons.zoom_in, 'Zoom +',
            _zoomSupported && _zoom < 100 ? () => onCommand('zoom/${(_zoom + 10).clamp(0, 100)}') : null),
          _action(context, Icons.refresh, 'Atualizar', onReconnect),
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
      Wrap(spacing: 8, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (_transmitting) _setting(context, 'Resolução', status['x-quality-profile'],
          const <String, String>{'360p': 'quality/360', '480p': 'quality/480',
            '720p': 'quality/720', '768p': 'quality/768', '1080p': 'quality/1080'}),
        if (_transmitting) _setting(context, 'FPS', status['x-fps-target'],
          const <String, String>{'5 FPS': 'fps/5', '10 FPS': 'fps/10',
            '15 FPS': 'fps/15', '24 FPS': 'fps/24', '30 FPS': 'fps/30'}),
        if (_transmitting && _torchSupported)
          _setting(context, 'Lanterna', status['x-torch-mode'],
            const <String, String>{'Desligar': 'torch/off', '30 s': 'torch/30',
              '120 s': 'torch/120', 'Durante REC': 'torch/record'}),
        if (_transmitting && allowCodecChange)
          _setting(context, 'Codec', _codec.toUpperCase(),
            const <String, String>{'MJPEG': 'codec/mjpeg', 'H.264': 'codec/h264'}),
      ]),
      const SizedBox(height: 8),
      if (_transmittingKnown && !_transmitting)
        Text('Transmissão pausada. Câmera e codificação desligadas; controle local ainda disponível.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      Wrap(spacing: 12, runSpacing: 4, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_recording ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
            size: 14, color: _recording ? scheme.error : scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(_recordingKnown ? (_recording ? 'Gravando no transmissor' : 'Gravação desligada')
              : 'Gravação sem confirmação',
            style: TextStyle(fontSize: 12, color: _recording ? scheme.error : scheme.onSurfaceVariant)),
        ]),
        Text('Zoom: ${_zoomSupported ? '$_zoom%' : 'indisponível'}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Text('FPS medido: ${status['x-fps-measured'] ?? '—'}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Text('Bateria: ${status['x-battery-level'] ?? '—'}%',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        if (int.tryParse(status['x-battery-temp-tenths'] ?? '') != null)
          Text('Bateria: ${(int.parse(status['x-battery-temp-tenths']!) / 10).toStringAsFixed(1)} °C',
            style: TextStyle(fontSize: 12,
              color: (int.parse(status['x-battery-temp-tenths']!) >= 420)
                  ? scheme.error : scheme.onSurfaceVariant)),
      ]),
    ]);
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
  const McrpLiveRemoteControls({super.key, required this.liveUrl});
  final String liveUrl;

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
    if (widget.liveUrl != oldWidget.liveUrl) _connect();
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
      setState(() { _status = status; _ready = true; _error = null; });
    } catch (_) {
      if (mounted && current == _generation && client == _client) {
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
          if (sent) _ready = false;
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
    _client?.close();
    super.dispose();
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
            Icon(_ready ? Icons.wifi : Icons.wifi_off,
              size: 17, color: _ready ? scheme.primary : scheme.error),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 7),
            Text(_error!, style: TextStyle(fontSize: 12, color: scheme.error)),
          ],
          const SizedBox(height: 9),
          if (!_ready)
            Text('REC: estado desconhecido durante a desconexão.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          if (!_ready)
            OutlinedButton.icon(onPressed: _busy ? null : () => unawaited(_refresh()),
              icon: const Icon(Icons.refresh), label: const Text('Conectar controles'))
          else
            McrpControlPanel(status: _status, working: _busy,
              compact: true, onCommand: _command,
              onReconnect: () => unawaited(_refresh())),
          const SizedBox(height: 5),
          Text('Parar transmissão libera câmera e encoder; o serviço mantém a escuta local. '
              'Iniciar vídeo requer que o serviço esteja ativo e o Android permita reabrir a câmera. '
              'Iniciar/Parar REC grava no celular transmissor. Uma gravação ativa '
              'não depende da conexão com o receptor. Para enviar novos comandos, '
              'os aparelhos precisam estar conectados na rede local.',
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
