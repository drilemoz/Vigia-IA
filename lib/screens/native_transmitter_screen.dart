import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../widgets/main_navigation_bar.dart';
import '../widgets/main_navigation_routes.dart';
import '../services/mcrp_client.dart';
import '../services/native_camera_transmitter_service.dart';
import '../services/native_platform_service.dart';
import 'launch_mode_screen.dart';

/// Modo transmissor padrão do Vigia IA: serviço nativo MCRP v1 e MJPEG.
/// A transmissão continua ao sair desta tela, até parada explícita.
class NativeTransmitterScreen extends StatefulWidget {
  const NativeTransmitterScreen({super.key});

  @override
  State<NativeTransmitterScreen> createState() => _NativeTransmitterScreenState();
}

class _NativeTransmitterScreenState extends State<NativeTransmitterScreen> {
  final NativePlatformService _permissions = NativePlatformService.instance;
  NativeTransmitterStatus? _status;
  Map<String, String> _details = const {};
  Timer? _timer;
  bool _busy = false;
  bool _refreshing = false;
  bool _localCommandBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final status = await NativeCameraTransmitterService.status();
      Map<String, String> details = const {};
      if (status.ready && status.url != null) {
        McrpClient? client;
        try {
          client = McrpClient(McrpAddress.parse(status.url!));
          details = await client.status();
        } catch (_) { /* Falha transitoria ao publicar os primeiros quadros. */ }
        finally { client?.close(); }
      }
      if (mounted) setState(() { _status = status; _details = details; });
    } catch (error) {
      if (mounted) setState(() => _error = 'Estado nativo indisponível: $error');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (!await _permissions.requestCameraPermission()) {
        throw StateError('Permita acesso à câmera nas configurações do Android.');
      }
      final permission = await _permissions.localNetworkPermissionStatus();
      if (permission.required && !permission.granted &&
          !await _permissions.requestLocalNetworkPermission()) {
        throw StateError('Permita o acesso à rede local.');
      }
      await _permissions.requestNotificationPermission();
      if (!mounted) return;
      await NativeCameraTransmitterService.start();
    } catch (error) {
      if (mounted) setState(() => _error = 'Falha ao iniciar: $error');
    } finally {
      if (mounted) { setState(() => _busy = false); unawaited(_refresh()); }
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try { await NativeCameraTransmitterService.stop(); }
    catch (error) { if (mounted) setState(() => _error = 'Falha ao parar: $error'); }
    finally { if (mounted) { setState(() => _busy = false); unawaited(_refresh()); } }
  }

  Future<void> _record() async {
    if (_localCommandBusy || _busy) return;
    setState(() { _localCommandBusy = true; _error = null; });
    try {
      await NativeCameraTransmitterService.toggleRecording();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = 'Estado de gravação não confirmado: $error');
    } finally {
      if (mounted) setState(() => _localCommandBusy = false);
    }
  }

  Future<void> _command(String action) async {
    final url = _status?.url;
    if (url == null || _localCommandBusy || _busy) return;
    McrpClient? client;
    setState(() { _localCommandBusy = true; _error = null; });
    try {
      client = McrpClient(McrpAddress.parse(url));
      await client.command(action);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = 'Comando não confirmado: $error');
    } finally {
      client?.close();
      if (mounted) setState(() => _localCommandBusy = false);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link privado copiado.')));
  }

  String _elapsed(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final sec = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
    return '${minutes}min ${sec.toString().padLeft(2, '0')}s';
  }

  Widget _metric(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }

  Widget _localButton(String label, String command) => ActionChip(
    label: Text(label),
    onPressed: _localCommandBusy || _busy ? null : () => _command(command),
  );

  void _changeMode() {
    // Não interromper o serviço: o receptor pode continuar assistindo enquanto
    // o usuário navega. A parada exige ação explícita na tela ou notificação.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LaunchModeScreen(manualReview: false),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final running = s?.running == true;
    final busy = _busy || (s?.busy == true);
    final url = s?.ready == true ? s?.url : null;
    final recording = _details['x-recording'] == '1' || s?.recording == true;
    final scheme = Theme.of(context).colorScheme;
    final model = _details['x-device-model'];
    final temperature = int.tryParse(_details['x-battery-temp-tenths'] ?? '');
    final camera = _details['x-camera-facing'] == '1' ? 'Frontal' : 'Traseira';
    return AdaptiveMainScaffold(
      currentIndex: 3,
      onDestinationSelected: (index) =>
          navigateToMainDestination(context, index, currentIndex: -1),
      appBar: AppBar(
        title: const Text('Vigia IA · transmissor'),
        actions: [
          IconButton(
            onPressed: _changeMode,
            tooltip: 'Alterar modo',
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(running ? Icons.sensors_rounded : Icons.videocam_off_outlined,
                    color: running ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(running ? 'Transmissão ativa' : 'Transmissão desligada',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(running ? 'O outro Vigia IA pode assistir e controlar'
                      : 'Inicie com a câmera e a rede local autorizadas',
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
              ]),
              if (running) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  _metric(Icons.timer_outlined, _elapsed(s!.seconds)),
                  _metric(recording ? Icons.fiber_manual_record : Icons.videocam_outlined,
                      recording ? 'REC ativo' : 'REC desligado'),
                  if (_details['x-battery-level'] != null)
                    _metric(Icons.battery_std, '${_details['x-battery-level']}%'),
                  if (temperature != null)
                    _metric(Icons.thermostat_outlined, '${(temperature / 10).toStringAsFixed(1)} °C'),
                  if (_details['x-fps-measured'] != null)
                    _metric(Icons.speed, '${_details['x-fps-measured']} FPS'),
                  if (_details['x-quality-profile'] != null)
                    _metric(Icons.high_quality_outlined, '${_details['x-quality-profile']}p'),
                  if (_details['x-camera-facing'] != null)
                    _metric(Icons.cameraswitch_outlined, camera),
                ]),
                if (model != null && model.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text('Aparelho: $model', style: Theme.of(context).textTheme.bodySmall)),
                if (!s.ready)
                  const Padding(padding: EdgeInsets.only(top: 8),
                    child: Text('Aguardando a câmera disponibilizar quadros…')),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : (running ? _stop : _start),
                icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(busy ? 'Aguarde…' : running ? 'Parar transmissão' : 'Iniciar transmissão'),
              ),
              if (running) ...[
                const SizedBox(height: 9),
                Text('A gravação pode ser iniciada ou parada pelo painel Ao vivo do receptor. '
                    'Depois de iniciada, continua no transmissor mesmo se o Wi-Fi cair.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          )),
          if (_error != null || s?.error != null) ...[
            const SizedBox(height: 8),
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(
              _error ?? s!.error!, style: TextStyle(color: scheme.error)))),
          ],
          if (url != null) ...[
            const SizedBox(height: 8),
            Card(child: ExpansionTile(
              key: const PageStorageKey<String>('vigia-transmitter-pairing'),
              leading: const Icon(Icons.qr_code_2_outlined),
              title: const Text('Parear outro celular'),
              subtitle: const Text('QR e endereço privado · toque para mostrar'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                const SizedBox(height: 4),
                Container(color: Colors.white, padding: const EdgeInsets.all(10),
                    child: QrImageView(data: url, size: 196, backgroundColor: Colors.white)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: () => _copy(url),
                  icon: const Icon(Icons.copy), label: const Text('Copiar endereço privado')),
                Text('O QR contém a chave de controle. Não o compartilhe fora da rede local.',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
            const SizedBox(height: 8),
            Card(child: ExpansionTile(
              key: const PageStorageKey<String>('vigia-transmitter-fallback'),
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Controles locais de emergência'),
              subtitle: const Text('Use normalmente o controle remoto no Ao vivo'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              children: [
                const SizedBox(height: 5),
                OutlinedButton.icon(
                  onPressed: busy || _localCommandBusy || s?.ready != true ? null : _record,
                  icon: Icon(recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record_rounded),
                  label: Text(recording ? 'Parar gravação local' : 'Iniciar gravação local'),
                ),
                const SizedBox(height: 5),
                Wrap(spacing: 7, runSpacing: 5, children: [
                  _localButton('Foto', 'photo'),
                  _localButton('Traseira', 'camera/back'),
                  _localButton('Frontal', 'camera/front'),
                  _localButton('Eco', 'eco/enable'),
                  _localButton('Normal', 'eco/disable'),
                  _localButton('5 FPS', 'fps/5'),
                  _localButton('10 FPS', 'fps/10'),
                  _localButton('480p', 'quality/480'),
                  _localButton('720p', 'quality/720'),
                  _localButton('Lanterna 30s', 'torch/30'),
                  _localButton('Lanterna off', 'torch/off'),
                ]),
              ],
            )),
          ],
          const SizedBox(height: 10),
          Text('O serviço Android transmite sem prévia local. Ele continua ativo '
              'ao sair desta tela, até ser interrompido aqui ou pela notificação do Android.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text('Transmissão pela rede local. Ajustes e REC remoto disponíveis no Ao vivo.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
