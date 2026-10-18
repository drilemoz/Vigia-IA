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

/// Transmissor Kotlin/MCRP v1, sem prévia Flutter ou câmera duplicada.
/// O serviço foreground continua ativo ao sair desta tela ou apagar a tela.
class NativeTransmitterScreen extends StatefulWidget {
  const NativeTransmitterScreen({super.key});

  @override
  State<NativeTransmitterScreen> createState() => _NativeTransmitterScreenState();
}

class _TransmitterOption {
  const _TransmitterOption(this.label, this.command, this.icon);
  final String label;
  final String command;
  final IconData icon;
}

class _NativeTransmitterScreenState extends State<NativeTransmitterScreen>
    with WidgetsBindingObserver {
  final NativePlatformService _permissions = NativePlatformService.instance;
  NativeTransmitterStatus? _status;
  Map<String, String> _details = const {};
  Timer? _timer;
  bool _busy = false;
  bool _refreshing = false;
  bool _localCommandBusy = false;
  bool _foreground = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    // O status na UI e consultado a cada 3 s, sem capturar video no Flutter.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_foreground) unawaited(_refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing || !_foreground) return;
    _refreshing = true;
    try {
      final status = await NativeCameraTransmitterService.status();
      Map<String, String> details = const {};
      if (status.ready && status.url != null) {
        McrpClient? client;
        try {
          client = McrpClient(McrpAddress.parse(status.url!));
          details = await client.status();
        } catch (_) {
          // O servico pode estar abrindo a camera ou trocando de rede.
        } finally {
          client?.close();
        }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço privado copiado.')),
      );
    }
  }

  String _elapsed(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final sec = safe % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  Widget _metric(IconData icon, String label, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: color ?? scheme.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ]),
    );
  }

  Future<void> _showPairing(String url) async {
    const qrBlue = Color(0xFF075B97);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Parear dispositivo', style: theme.textTheme.titleLarge)),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Escaneie no Vigia IA receptor, na mesma rede local.',
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDEAF3)),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    QrImageView(
                      data: url,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: qrBlue,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square, color: qrBlue,
                      ),
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                    ),
                    // Selo reduzido para preservar o contraste e as margens do QR.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Vigia IA',
                          style: TextStyle(color: qrBlue, fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _copy(url),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar endereço privado'),
                ),
                const SizedBox(height: 8),
                Text('O QR contém uma chave de controle privada. Não o compartilhe fora da rede local.',
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOptions(String title, IconData icon,
      List<_TransmitterOption> options, String? selected) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Row(children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final option in options)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: selected == option.command
                    ? theme.colorScheme.primaryContainer : null,
                leading: Icon(option.icon),
                title: Text(option.label),
                trailing: selected == option.command
                    ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                onTap: () => Navigator.of(dialogContext).pop(option.command),
              ),
          ]),
          actions: [TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          )],
        );
      },
    );
    if (action != null && mounted && action != selected) await _command(action);
  }

  void _changeMode() {
    // Nao interromper o servico nem descadastrar receptores ao navegar.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LaunchModeScreen(manualReview: false),
      ),
      (_) => false,
    );
  }

  Widget _controlTile({required String label, required IconData icon,
      required VoidCallback? onPressed, bool selected = false}) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        backgroundColor: selected ? scheme.primaryContainer : null,
        foregroundColor: selected ? scheme.onPrimaryContainer : scheme.onSurface,
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 23),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _controls({required bool recording, required bool disabled}) {
    final scheme = Theme.of(context).colorScheme;
    final front = _details['x-camera-facing'] == '1';
    final eco = _details['x-eco'] == '1';
    final fps = _details['x-fps-target'] ?? 'FPS';
    final quality = _details['x-quality-profile'] ?? 'Resolução';
    final torch = _details['x-torch-enabled'] == '1';
    final canUse = !disabled && !_localCommandBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.tune_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Controles locais', style: Theme.of(context).textTheme.titleMedium),
              Text('Ajustes rápidos da câmera transmissora',
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth < 360 ? 3 : 4;
            const gap = 8.0;
            final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              SizedBox(width: itemWidth, height: 73, child: _controlTile(
                label: 'Foto', icon: Icons.photo_camera_outlined,
                onPressed: canUse ? () => _command('photo') : null)),
              SizedBox(width: itemWidth, height: 73, child: _controlTile(
                label: recording ? 'Parar REC' : 'Gravar',
                icon: recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record_rounded,
                selected: recording,
                onPressed: canUse ? _record : null)),
              SizedBox(width: itemWidth, height: 73, child: _controlTile(
                label: front ? 'Frontal' : 'Traseira', icon: Icons.cameraswitch_outlined,
                onPressed: canUse ? () => _showOptions('Câmera', Icons.cameraswitch_outlined, const [
                  _TransmitterOption('Traseira', 'camera/back', Icons.camera_rear_outlined),
                  _TransmitterOption('Frontal', 'camera/front', Icons.camera_front_outlined),
                ], front ? 'camera/front' : 'camera/back') : null)),
              SizedBox(width: itemWidth, height: 73, child: _controlTile(
                label: eco ? 'Eco' : 'Normal', icon: Icons.energy_savings_leaf_outlined,
                selected: eco,
                onPressed: canUse ? () => _showOptions('Perfil de energia', Icons.energy_savings_leaf_outlined, const [
                  _TransmitterOption('Eco', 'eco/enable', Icons.eco_outlined),
                  _TransmitterOption('Normal', 'eco/disable', Icons.speed_outlined),
                ], eco ? 'eco/enable' : 'eco/disable') : null)),
              SizedBox(width: itemWidth, height: 73, child: _controlTile(
                label: fps == 'FPS' ? fps : '$fps FPS', icon: Icons.speed_rounded,
                onPressed: canUse ? () => _showOptions('Quadros por segundo', Icons.speed_rounded, const [
                  _TransmitterOption('5 FPS', 'fps/5', Icons.slow_motion_video_rounded),
                  _TransmitterOption('10 FPS', 'fps/10', Icons.videocam_outlined),
                ], 'fps/$fps') : null)),
              SizedBox(width: itemWidth, height: 73, child: _controlTile(
                label: quality == 'Resolução' ? quality : '${quality}p',
                icon: Icons.high_quality_outlined,
                onPressed: canUse ? () => _showOptions('Resolução', Icons.high_quality_outlined, const [
                  _TransmitterOption('480p', 'quality/480', Icons.high_quality_outlined),
                  _TransmitterOption('720p', 'quality/720', Icons.hd_outlined),
                ], 'quality/$quality') : null)),
              SizedBox(width: itemWidth, height: 73, child: _controlTile(
                label: torch ? 'Lanterna on' : 'Lanterna', icon: Icons.flashlight_on_outlined,
                selected: torch,
                onPressed: canUse ? () => _showOptions('Lanterna', Icons.flashlight_on_outlined, const [
                  _TransmitterOption('Desligar', 'torch/off', Icons.flashlight_off_outlined),
                  _TransmitterOption('Ligar por 30 s', 'torch/30', Icons.flashlight_on_outlined),
                ], torch ? 'torch/30' : 'torch/off') : null)),
            ]);
          }),
          const SizedBox(height: 10),
          Text('Controles alternativos ao painel Ao vivo do receptor.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
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
    final recordSeconds = int.tryParse(_details['x-recording-seconds'] ?? '');
    return AdaptiveMainScaffold(
      currentIndex: 3,
      onDestinationSelected: (index) =>
          navigateToMainDestination(context, index, currentIndex: -1),
      appBar: AppBar(
        title: const Text('Vigia IA · Transmissão',
          maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: url == null ? null : () => _showPairing(url),
            tooltip: url == null ? 'QR disponível após iniciar' : 'Parear por QR Code',
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
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
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: (running ? scheme.primary : scheme.onSurfaceVariant)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(running ? Icons.sensors_rounded : Icons.videocam_off_outlined,
                      color: running ? scheme.primary : scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(running ? 'Transmissão ativa' : 'Transmissão desligada',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(running ? 'Disponível na rede local' : 'Inicie a câmera para transmitir',
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
                if (running)
                  Icon(Icons.circle, size: 11, color: scheme.tertiary),
              ]),
              if (running) ...[
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _durationPanel('TRANSMITINDO', _elapsed(s!.seconds),
                      Icons.wifi_tethering_rounded, scheme.primary)),
                  const SizedBox(width: 9),
                  Expanded(child: _durationPanel(recording ? 'GRAVANDO' : 'GRAVAÇÃO',
                      recording && recordSeconds != null ? _elapsed(recordSeconds) :
                      recording ? 'Em andamento' : 'Desligada',
                      recording ? Icons.fiber_manual_record : Icons.videocam_off_outlined,
                      recording ? scheme.error : scheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  if (_details['x-battery-level'] != null)
                    _metric(Icons.battery_std_rounded, '${_details['x-battery-level']}%'),
                  if (temperature != null)
                    _metric(Icons.thermostat_outlined,
                        '${(temperature / 10).toStringAsFixed(1)} °C'),
                  if (_details['x-fps-measured'] != null)
                    _metric(Icons.speed_rounded, '${_details['x-fps-measured']} FPS'),
                  if (_details['x-quality-profile'] != null)
                    _metric(Icons.high_quality_outlined, '${_details['x-quality-profile']}p'),
                  if (_details['x-camera-facing'] != null)
                    _metric(Icons.cameraswitch_outlined, camera),
                ]),
                if (model != null && model.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 10),
                    child: Text('Aparelho: $model', style: Theme.of(context).textTheme.bodySmall)),
                if (!s.ready)
                  const Padding(padding: EdgeInsets.only(top: 8),
                    child: Text('Aguardando a câmera disponibilizar quadros…')),
              ],
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: busy ? null : (running ? _stop : _start),
                icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(busy ? 'Aguarde…' : running ? 'Parar transmissão' : 'Iniciar transmissão'),
              )),
              if (running) ...[
                const SizedBox(height: 9),
                Text('O REC continua no transmissor mesmo se o Wi-Fi cair.',
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
            const SizedBox(height: 9),
            _controls(recording: recording, disabled: busy || s?.ready != true),
          ],
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text(
            'A câmera permanece transmitindo com a tela apagada ou fora desta tela. '
            'Para encerrar, use Parar transmissão ou a notificação do Android.',
            style: Theme.of(context).textTheme.bodySmall,
          )),
        ],
      ),
    );
  }

  Widget _durationPanel(String caption, String value, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(child: Text(caption,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall)),
        ]),
        const SizedBox(height: 5),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800, color: color))),
      ]),
    );
  }
}
