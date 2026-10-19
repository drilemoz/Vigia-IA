import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/camera_endpoint.dart';
import '../services/lan_camera_discovery_service.dart';
import '../services/lan_camera_subnet_scanner.dart';
import '../services/native_platform_service.dart';
import '../services/rtsp_connection_assistant.dart';

/// Cadastro RTSP assistido: inspirado no fluxo comprovado do Minha Câmera.
/// Um teste DESCRIBE valida um perfil; salvar não depende de vídeo confirmado.
class RtspCameraEditorDialog extends StatefulWidget {
  const RtspCameraEditorDialog({super.key, this.existing, this.initialName, this.initialAddress});
  final CameraEndpoint? existing;
  final String? initialName;
  final String? initialAddress;

  @override
  State<RtspCameraEditorDialog> createState() => _RtspCameraEditorDialogState();
}

class _RtspCameraEditorDialogState extends State<RtspCameraEditorDialog> {
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '554');
  final _path = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _scanCancel = LanScanCancelToken();
  final _candidates = <LanCameraCandidate>[];
  bool _passwordVisible = false;
  bool _softwareDecoding = false;
  bool _forceTcp = true;
  bool _busy = false;
  bool _scanning = false;
  bool _autoDetecting = false;
  int _checked = 0;
  int _total = 0;
  String? _error;
  String? _feedback;
  RtspProbeResult? _probeResult;
  String _pathSelection = '__custom__';

  @override
  void initState() {
    super.initState();
    final initial = widget.existing?.address ?? widget.initialAddress ?? '';
    _name.text = widget.existing?.name ?? widget.initialName ?? 'Câmera RTSP';
    _softwareDecoding = widget.existing?.rtspSoftwareDecoding ?? false;
    _forceTcp = widget.existing?.rtspForceTcp ?? true;
    _applyInitial(initial);
  }

  void _applyInitial(String raw) {
    final uri = RtspConnectionAssistant.parseInput(raw);
    if (uri != null) {
      _host.text = uri.host;
      _port.text = '${uri.hasPort ? uri.port : 554}';
      _path.text = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      final userInfo = uri.userInfo;
      if (userInfo.isNotEmpty) {
        final colon = userInfo.indexOf(':');
        _username.text = Uri.decodeComponent(colon >= 0 ? userInfo.substring(0, colon) : userInfo);
        _password.text = colon >= 0 ? Uri.decodeComponent(userInfo.substring(colon + 1)) : '';
      }
    } else if (raw.trim().isNotEmpty) {
      _host.text = RtspConnectionAssistant.normalizedHost(raw);
    }
    _syncPreset();
  }

  void _syncPreset() {
    final current = RtspConnectionAssistant.normalizedPath(_path.text);
    _pathSelection = RtspConnectionAssistant.paths.any((item) => item.path == current)
        ? current : '__custom__';
  }

  void _changed() {
    setState(() {
      _error = null;
      _feedback = null;
      _probeResult = null;
      _syncPreset();
    });
  }

  @override
  void dispose() {
    _scanCancel.cancel();
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _path.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  (String, int)? _validatedAddress() {
    final raw = _host.text.trim();
    if (raw.toLowerCase().startsWith('rtsp://')) {
      final uri = RtspConnectionAssistant.parseInput(raw);
      if (uri == null) return null;
      return (uri.host, uri.hasPort ? uri.port : 554);
    }
    final port = int.tryParse(_port.text.trim());
    if (!RtspConnectionAssistant.validHost(raw) || port == null || port <= 0 || port > 65535) {
      return null;
    }
    return (raw, port);
  }

  void _takeUrl(String text) {
    final uri = RtspConnectionAssistant.parseInput(text);
    if (uri == null) {
      setState(() => _error = 'Cole uma URL iniciada por rtsp:// com IP ou host válido.');
      return;
    }
    setState(() {
      _applyInitial(text);
      _error = null;
      _feedback = 'Endereço, porta, caminho e credenciais preenchidos pela URL.';
      _probeResult = null;
    });
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    _takeUrl(data?.text ?? '');
  }

  void _addCandidate(LanCameraCandidate candidate, String gateway) {
    if (!mounted || _scanCancel.cancelled || candidate.host == gateway) return;
    if (candidate.kind == LanCameraKind.vigiaIa || candidate.port == 8765) return;
    if (!RtspConnectionAssistant.isPrivateIpv4(candidate.host)) return;
    final index = _candidates.indexWhere((item) => item.host == candidate.host);
    if (index < 0) {
      if (_candidates.length < 48) _candidates.add(candidate);
    } else if (candidate.kind == LanCameraKind.rtsp || candidate.kind == LanCameraKind.onvif) {
      _candidates[index] = candidate;
    }
    _candidates.sort((a, b) => a.host.compareTo(b.host));
    setState(() {});
  }

  Future<void> _scanNetwork() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _scanning = true;
      _error = null;
      _feedback = 'Procurando câmeras na rede Wi-Fi…';
      _candidates.clear();
      _checked = 0;
      _total = 0;
    });
    try {
      final native = NativePlatformService.instance;
      final permission = await native.localNetworkPermissionStatus();
      if (permission.required && !permission.granted &&
          !await native.requestLocalNetworkPermission()) {
        throw StateError('Conceda permissão de acesso à rede local.');
      }
      final range = await LanCameraSubnetScanner.localRange();
      if (!mounted) return;
      if (range.hosts.isEmpty) throw StateError(range.warning ?? 'Nenhuma rede Wi-Fi IPv4 encontrada.');
      _total = range.hosts.length;
      await LanCameraSubnetScanner.multicast(true);
      try {
        await Future.wait(<Future<void>>[
          LanCameraDiscoveryService.discover(
            timeout: const Duration(seconds: 6),
            targetBroadcasts: range.broadcast.isEmpty ? null : [range.broadcast],
            cancelled: () => _scanCancel.cancelled,
            onFound: (candidate) => _addCandidate(candidate, range.gateway),
          ).then((_) {}),
          LanCameraSubnetScanner.scan(
            range: range,
            cancel: _scanCancel,
            onFound: (candidate) => _addCandidate(candidate, range.gateway),
            onProgress: (checked, total) {
              if (!mounted) return;
              setState(() {
                _checked = checked;
                _total = total;
              });
            },
          ),
        ]);
      } finally {
        await LanCameraSubnetScanner.multicast(false);
      }
      if (!mounted) return;
      setState(() => _feedback = _candidates.isEmpty
          ? 'Nenhuma câmera identificada. Confira Wi-Fi e isolamento dos aparelhos.'
          : '${_candidates.length} dispositivo(s) encontrado(s). Escolha um endereço abaixo.');
    } catch (_) {
      if (mounted) setState(() => _feedback = 'Não foi possível procurar na rede. Confira Wi-Fi e permissões.');
    } finally {
      if (mounted) setState(() { _busy = false; _scanning = false; });
    }
  }

  void _selectCandidate(String host) {
    final candidate = _candidates.where((item) => item.host == host).firstOrNull;
    if (candidate == null) return;
    setState(() {
      _host.text = candidate.host;
      _port.text = '${candidate.kind == LanCameraKind.rtsp ? candidate.port ?? 554 : 554}';
      if (_name.text.trim().isEmpty || _name.text == 'Câmera RTSP') {
        _name.text = 'Câmera ${candidate.host}';
      }
      _error = null;
      _feedback = candidate.kind == LanCameraKind.onvif
          ? 'ONVIF detectado. Agora detecte o caminho RTSP; o serviço ONVIF não confirma o vídeo.'
          : candidate.kind == LanCameraKind.rtsp
              ? 'Serviço RTSP identificado. Detecte o caminho do vídeo.'
              : 'Dispositivo encontrado; RTSP ainda não comprovado.';
      _probeResult = null;
    });
  }

  Future<void> _test({required bool auto}) async {
    if (_busy) return;
    final data = _validatedAddress();
    if (data == null) {
      setState(() => _error = 'Informe um IP/host e uma porta entre 1 e 65535.');
      return;
    }
    final (host, port) = data;
    if (!RtspConnectionAssistant.isPrivateIpv4(host)) {
      setState(() => _error = 'A detecção de caminhos é limitada à rede local privada.');
      return;
    }
    setState(() {
      _busy = true;
      _autoDetecting = auto;
      _error = null;
      _feedback = auto ? 'Verificando caminhos RTSP…' : 'Testando vídeo RTSP…';
      _probeResult = null;
      _checked = 0;
      _total = 0;
    });
    try {
      final user = _username.text.trim();
      final pass = _password.text;
      if (auto) {
        final (path, result) = await RtspConnectionProbe.findVideo(
          host: host, port: port, username: user, password: pass,
          initialPath: _path.text,
          cancelled: () => !mounted || _scanCancel.cancelled,
          onProgress: (checked, total) {
            if (!mounted) return;
            setState(() { _checked = checked; _total = total; });
          },
        );
        if (!mounted) return;
        setState(() {
          _probeResult = result;
          if (path != null) {
            _path.text = path;
            _syncPreset();
          }
          _feedback = result.message;
        });
      } else {
        final result = await RtspConnectionProbe.test(
          host: host, port: port, path: _path.text,
          username: user, password: pass);
        if (!mounted) return;
        setState(() { _probeResult = result; _feedback = result.message; });
      }
    } finally {
      if (mounted) setState(() { _busy = false; _autoDetecting = false; });
    }
  }

  void _save() {
    final data = _validatedAddress();
    if (data == null) {
      setState(() => _error = 'Informe IP/host válido e porta RTSP.');
      return;
    }
    final (host, port) = data;
    final url = RtspConnectionAssistant.buildUrl(
      host: host, port: port, path: _path.text,
      username: _username.text.trim(), password: _password.text);
    if (url == null) {
      setState(() => _error = 'Confira o caminho do vídeo. Ex.: /stream1 ou /cam/realmonitor?channel=1&subtype=0.');
      return;
    }
    Navigator.pop(context, CameraEndpoint(
      id: widget.existing?.id ?? 'cam_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim().isEmpty ? 'Câmera $host' : _name.text.trim(),
      type: CameraEndpointType.rtsp,
      address: url,
      enabled: widget.existing?.enabled ?? true,
      countingEnabled: widget.existing?.countingEnabled ?? false,
      rtspSoftwareDecoding: _softwareDecoding,
      rtspForceTcp: _forceTcp,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final currentPreview = RtspConnectionAssistant.buildUrl(
      host: _host.text.trim(), port: int.tryParse(_port.text.trim()) ?? -1,
      path: _path.text) ?? '';
    final success = _probeResult?.verifiedVideo == true;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(22, 14, 10, 0),
      title: Row(children: [
        const Icon(Icons.videocam_outlined),
        const SizedBox(width: 10),
        const Expanded(child: Text('Conectar RTSP', style: TextStyle(fontSize: 21))),
        IconButton(onPressed: () => Navigator.pop(context),
          tooltip: 'Fechar', icon: const Icon(Icons.close_rounded)),
      ]),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 70).clamp(150.0, 510.0).toDouble(),
        child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Preencha manualmente, cole uma URL ou encontre a câmera no Wi-Fi.',
              style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(controller: _name,
              decoration: const InputDecoration(labelText: 'Nome da câmera',
                isDense: true, prefixIcon: Icon(Icons.drive_file_rename_outline))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(
                controller: _host,
                autocorrect: false,
                keyboardType: TextInputType.url,
                onChanged: (value) {
                  if (value.trim().toLowerCase().startsWith('rtsp://') &&
                      RtspConnectionAssistant.parseInput(value) != null) {
                    _takeUrl(value);
                  } else { _changed(); }
                },
                decoration: const InputDecoration(
                  isDense: true, labelText: 'IP ou host',
                  hintText: '192.168.1.20', prefixIcon: Icon(Icons.router_outlined)),
              )),
              const SizedBox(width: 8),
              SizedBox(width: 88, child: TextField(
                controller: _port, keyboardType: TextInputType.number,
                onChanged: (_) => _changed(),
                decoration: const InputDecoration(labelText: 'Porta', isDense: true),
              )),
            ]),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: _busy ? null : _pasteUrl,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Colar URL completa'),
            )),
            DropdownButtonFormField<String>(
              key: ValueKey(_pathSelection),
              initialValue: _pathSelection,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Caminho do vídeo',
                prefixIcon: Icon(Icons.alt_route_rounded), isDense: true),
              items: <DropdownMenuItem<String>>[
                ...RtspConnectionAssistant.paths.map((item) => DropdownMenuItem<String>(
                  value: item.path, child: Text(item.label, overflow: TextOverflow.ellipsis))),
                const DropdownMenuItem<String>(value: '__custom__',
                  child: Text('Personalizado…')),
              ],
              onChanged: _busy ? null : (selection) {
                if (selection == null) return;
                setState(() {
                  _pathSelection = selection;
                  if (selection != '__custom__') _path.text = selection;
                  _error = null; _feedback = null; _probeResult = null;
                });
              },
            ),
            if (_pathSelection == '__custom__') ...[
              const SizedBox(height: 8),
              TextField(controller: _path, autocorrect: false,
                onChanged: (_) {
                  setState(() {
                    _error = null; _feedback = null; _probeResult = null;
                  });
                },
                decoration: const InputDecoration(isDense: true,
                  labelText: 'Caminho RTSP personalizado',
                  hintText: '/stream1 ou /cam/realmonitor?channel=1&subtype=0'),
              ),
            ],
            const SizedBox(height: 10),
            TextField(controller: _username, autocorrect: false,
              onChanged: (_) => _changed(),
              decoration: const InputDecoration(isDense: true, labelText: 'Usuário (se necessário)',
                prefixIcon: Icon(Icons.person_outline_rounded), hintText: 'admin'))),
            const SizedBox(height: 10),
            TextField(controller: _password, autocorrect: false,
              obscureText: !_passwordVisible, enableSuggestions: false,
              onChanged: (_) => _changed(),
              decoration: InputDecoration(isDense: true, labelText: 'Senha RTSP',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible ? 'Ocultar senha' : 'Mostrar senha',
                  icon: Icon(_passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible)),
              )),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 3, children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _scanNetwork,
                icon: const Icon(Icons.wifi_find, size: 18),
                label: const Text('Buscar no Wi-Fi')),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _test(auto: true),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Detectar stream')),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _test(auto: false),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Testar URL')),
            ]),
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              if (_checked > 0 && _total > 0) Text(
                _scanning ? 'Endereços: $_checked/$_total'
                    : _autoDetecting ? 'Caminhos: $_checked/$_total' : 'Testando…',
                style: theme.textTheme.bodySmall),
            ],
            if (_candidates.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dispositivos encontrados',
                  prefixIcon: Icon(Icons.devices_rounded), isDense: true),
                items: _candidates.map((item) => DropdownMenuItem<String>(
                  value: item.host,
                  child: Text('${item.host} · ${item.kind.name.toUpperCase()}',
                    overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) { if (value != null) _selectCandidate(value); },
              ),
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(success ? Icons.verified_rounded : Icons.info_outline_rounded,
                  color: success ? color.primary : color.onSurfaceVariant, size: 19),
                const SizedBox(width: 7),
                Expanded(child: Text(_feedback!, style: theme.textTheme.bodySmall)),
              ]),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: color.error)),
            ],
            if (currentPreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(currentPreview, style: theme.textTheme.labelSmall),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Opções avançadas', style: TextStyle(fontSize: 14)),
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Priorizar RTSP por TCP'),
                  subtitle: const Text('Melhor em Wi-Fi instável. Desative para usar o transporte padrão do VLC (geralmente UDP).'),
                  value: _forceTcp,
                  onChanged: (value) => setState(() => _forceTcp = value),
                ),
                SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Decodificação por software'),
                subtitle: const Text('Usar se houver problema na imagem; maior consumo de CPU/bateria.'),
                value: _softwareDecoding,
                onChanged: (value) => setState(() => _softwareDecoding = value),
              )],
            ),
            Text('Salvar não confirma que o vídeo funciona. Para evitar tentativas desnecessárias, use “Testar URL” antes de abrir a câmera.',
              style: theme.textTheme.bodySmall),
          ],
        )),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(onPressed: _busy ? null : _save,
          icon: const Icon(Icons.check_rounded), label: const Text('Salvar')),
      ],
    );
  }
}
