import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/mcrp_client.dart';
import '../services/native_camera_transmitter_service.dart';
import '../services/native_platform_service.dart';

/// Primeira etapa da migracao do Minha Camera: motor nativo em paralelo ao legado.
/// MCRP v1, MJPEG, controle remoto e captura com tela apagada (a validar no A3).
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
    try { await NativeCameraTransmitterService.toggleRecording(); await _refresh(); }
    catch (error) { if (mounted) setState(() => _error = 'Falha na gravação: $error'); }
  }

  Future<void> _command(String action) async {
    final url = _status?.url;
    if (url == null) return;
    McrpClient? client;
    try {
      client = McrpClient(McrpAddress.parse(url));
      await client.command(action);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = 'Comando rejeitado: $error');
    } finally { client?.close(); }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link privado copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final running = s?.running == true;
    final busy = _busy || (s?.busy == true);
    final url = s?.ready == true ? s?.url : null;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Transmissor nativo · experimental')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(running ? Icons.sensors : Icons.videocam_off_outlined,
                    color: running ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(running ? 'Serviço Android ativo' : 'Transmissão desligada',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              Text('Estado: ${s?.phase ?? 'consultando…'}'),
              if (running) Text('Tempo de transmissão: ${s!.seconds}s'),
              if (running && !s!.ready) const Text('Aguardando o primeiro quadro da câmera…'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : (running ? _stop : _start),
                icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(busy ? 'Aguarde…' : running ? 'Parar transmissão' : 'Iniciar transmissão nativa'),
              ),
              if (running) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy || !s!.ready ? null : _record,
                  icon: Icon(s.recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record_rounded),
                  label: Text(s.recording ? 'Parar gravação' : 'Gravar no transmissor'),
                ),
              ],
            ]),
          )),
          if (_error != null || s?.error != null) ...[
            const SizedBox(height: 8),
            Text(_error ?? s!.error!, style: TextStyle(color: scheme.error)),
          ],
          if (url != null) ...[
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              const Text('Conecte o segundo celular pelo QR',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(color: Colors.white, padding: const EdgeInsets.all(12),
                  child: QrImageView(data: url, size: 200, backgroundColor: Colors.white)),
              const SizedBox(height: 8),
              SelectableText(url, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
              TextButton.icon(onPressed: () => _copy(url),
                  icon: const Icon(Icons.copy), label: const Text('Copiar endereço privado')),
              const Text('Não compartilhe este QR fora da sua rede local. Ele contém a chave de controle.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ]))),
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Controle local MCRP', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('FPS medido: ${_details['x-fps-measured'] ?? '...'} · '
                    'Bateria: ${_details['x-battery-level'] ?? '...'}% · '
                    'REC: ${s?.recording == true ? 'sim' : 'não'}'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  ActionChip(label: const Text('Foto'), onPressed: () => _command('photo')),
                  ActionChip(label: const Text('Câmera traseira'), onPressed: () => _command('camera/back')),
                  ActionChip(label: const Text('Câmera frontal'), onPressed: () => _command('camera/front')),
                  ActionChip(label: const Text('Eco'), onPressed: () => _command('eco/enable')),
                  ActionChip(label: const Text('Normal'), onPressed: () => _command('eco/disable')),
                  ActionChip(label: const Text('FPS 5'), onPressed: () => _command('fps/5')),
                  ActionChip(label: const Text('FPS 10'), onPressed: () => _command('fps/10')),
                  ActionChip(label: const Text('480p'), onPressed: () => _command('quality/480')),
                  ActionChip(label: const Text('720p'), onPressed: () => _command('quality/720')),
                  ActionChip(label: const Text('Lanterna 30s'), onPressed: () => _command('torch/30')),
                  ActionChip(label: const Text('Lanterna off'), onPressed: () => _command('torch/off')),
                ]),
              ],
            ))),
          ],
          const SizedBox(height: 12),
          const Text('Nesta etapa o serviço Kotlin opera sem prévia local para reduzir consumo. '
              'Os quadros são transmitidos em MJPEG e podem ser vistos no Ao vivo do outro Vigia IA. '
              'Ao sair desta tela, o serviço continua até você tocar em Parar ou na notificação Android.'),
          const SizedBox(height: 8),
          const Text('Beta: use o modo de transmissão Flutter anterior caso o serviço nativo '
              'apresente incompatibilidade no seu aparelho.'),
        ],
      ),
    );
  }
}
