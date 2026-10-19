import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vlc_player/vlc_player.dart';

import '../services/mcrp_client.dart';
import '../services/mcrp_saved_cameras_store.dart';
import '../services/native_platform_service.dart';
import '../services/remote_gallery_storage.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/main_navigation_routes.dart';

/// Galeria do transmissor (Minha Câmera/MCRP) acessível independentemente do
/// visor ao vivo. Downloads nunca apagam o original do telefone remoto.
class RemoteGalleryScreen extends StatefulWidget {
  const RemoteGalleryScreen({super.key, this.savedStore, this.storage});

  final McrpSavedCamerasStore? savedStore;
  final RemoteGalleryStorage? storage;

  @override
  State<RemoteGalleryScreen> createState() => _RemoteGalleryScreenState();
}

class _RemoteGalleryScreenState extends State<RemoteGalleryScreen> {
  late final McrpSavedCamerasStore _savedStore;
  late final RemoteGalleryStorage _storage;
  final _selected = <String>{};
  List<SavedMcrpCamera> _devices = const [];
  List<McrpMediaItem> _remoteItems = const [];
  List<File> _localFiles = const [];
  McrpClient? _client;
  String _deviceName = 'Nenhum aparelho';
  String _filter = 'all';
  bool _remoteTab = true;
  bool _loading = false;
  bool _transferring = false;
  bool _cancelTransfer = false;
  int _completed = 0;
  int _total = 0;
  int _received = 0;
  int _expected = 0;
  DateTime? _lastProgressUiAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _savedStore = widget.savedStore ?? McrpSavedCamerasStore();
    _storage = widget.storage ?? const RemoteGalleryStorage();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _cancelTransfer = true;
    _client?.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final devices = await _savedStore.load();
      final local = await _storage.savedFiles();
      if (!mounted) return;
      setState(() { _devices = devices; _localFiles = local; });
      if (devices.length == 1) await _connect(devices.first);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar os aparelhos salvos.');
    }
  }

  Future<void> _connect(SavedMcrpCamera device) async {
    if (_loading || _transferring) return;
    setState(() { _loading = true; _error = null; });
    McrpClient? next;
    try {
      next = McrpClient(McrpAddress.parse(device.liveUrl));
      final info = await next.info();
      final capabilities = info['capabilities'];
      if (capabilities is! Map || capabilities['media'] != true) {
        throw const FormatException('Este transmissor não oferece Galeria MCRP.');
      }
      final items = (await next.media()).where(RemoteGalleryStorage.supported).toList();
      items.sort((a, b) => b.modified.compareTo(a.modified));
      if (!mounted) { next.close(); return; }
      _client?.close();
      setState(() {
        _client = next;
        _deviceName = device.name;
        _remoteItems = items;
        _selected.clear();
        _remoteTab = true;
      });
    } catch (error) {
      next?.close();
      if (mounted) setState(() => _error = 'Aparelho indisponível: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_transferring || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final client = _client;
      if (client != null) {
        final items = (await client.media()).where(RemoteGalleryStorage.supported).toList();
        items.sort((a, b) => b.modified.compareTo(a.modified));
        if (mounted && _client == client) {
          setState(() {
            _remoteItems = items;
            _selected.removeWhere((id) => !items.any((item) => item.id == id));
          });
        }
      }
      final local = await _storage.savedFiles();
      if (mounted) setState(() => _localFiles = local);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível atualizar. Confira o Wi-Fi e o transmissor.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseDevice() async {
    if (_transferring || _loading) return;
    final choice = await showModalBottomSheet<SavedMcrpCamera>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Aparelhos salvos', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_devices.isEmpty) const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Nenhum celular salvo'),
            subtitle: Text('Adicione o endereço MCRP ou leia o QR do A3.'),
          ),
          ..._devices.map((device) => ListTile(
            leading: const Icon(Icons.smartphone_outlined),
            title: Text(device.name),
            subtitle: Text(device.networkAddress),
            onTap: () => Navigator.of(ctx).pop(device),
          )),
        ]),
      )),
    );
    if (choice != null && mounted) await _connect(choice);
  }

  Future<void> _addDevice({String? scanned}) async {
    if (_transferring || _loading) return;
    final field = TextEditingController(text: scanned ?? '');
    final name = TextEditingController(text: 'Redmi A3');
    SavedMcrpCamera? saved;
    try {
      final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Adicionar transmissor'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Informe a URL privada /live/ exibida no A3. O token fica apenas neste aparelho.'),
          const SizedBox(height: 12),
          TextField(controller: name, maxLength: 48,
              decoration: const InputDecoration(labelText: 'Nome do aparelho')),
          TextField(controller: field, keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL ou QR MCRP')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salvar')),
        ],
      ));
      if (result != true || !mounted) return;
      final address = McrpAddress.parse(field.text);
      final label = name.text.trim();
      final devices = await _savedStore.save(name: label, liveUrl: address.liveUrl.toString());
      saved = devices.first;
      if (mounted) setState(() => _devices = devices);
    } catch (_) {
      if (mounted) setState(() => _error = 'Endereço ou nome inválido. Use o QR privado do A3.');
    } finally {
      field.dispose();
      name.dispose();
    }
    if (saved != null && mounted) await _connect(saved);
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const _GalleryQrScanner(),
    ));
    if (result != null && mounted) await _addDevice(scanned: result);
  }

  Future<void> _download(List<McrpMediaItem> items) async {
    final client = _client;
    if (_transferring || _loading || client == null || items.isEmpty) return;
    setState(() {
      _transferring = true;
      _cancelTransfer = false;
      _completed = 0;
      _total = items.length;
      _received = 0;
      _expected = 0;
      _lastProgressUiAt = null;
      _error = null;
    });
    var failures = 0;
    var fresh = 0;
    try {
      for (final item in items) {
        if (_cancelTransfer || !mounted) break;
        try {
          final result = await _storage.receive(client, item,
            isCancelled: () => _cancelTransfer || !mounted,
            onProgress: (received, total) {
              final now = DateTime.now();
              final previous = _lastProgressUiAt;
              if (mounted && (previous == null ||
                  now.difference(previous) >= const Duration(milliseconds: 250) ||
                  received == total)) {
                _lastProgressUiAt = now;
                setState(() { _received = received; _expected = total; });
              }
            },
          );
          if (!result.alreadySaved) {
            fresh++;
            if (item.mime == 'image/jpeg' || item.mime == 'image/png' ||
                item.mime == 'image/webp' || item.mime == 'video/mp4' ||
                item.mime == 'video/webm' || item.mime == 'video/3gpp') {
              try {
                await NativePlatformService.instance.publishCameraMedia(
                  path: result.file.path, fileName: item.name, mimeType: item.mime,
                );
              } catch (_) {
                // A cópia privada continua íntegra e pode ser vista em Recebidos.
              }
            }
          }
        } catch (_) {
          if (_cancelTransfer) break;
          failures++;
        }
        if (mounted) setState(() {
          _completed++;
          _received = 0;
          _expected = 0;
          _lastProgressUiAt = null;
        });
      }
      final local = await _storage.savedFiles();
      if (mounted) {
        setState(() { _localFiles = local; _selected.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_cancelTransfer
              ? 'Transferência cancelada. Arquivos concluídos foram preservados.'
              : 'Concluído: $fresh novo(s), $failures falha(s). Veja a aba Recebidos.'),
        ));
      }
    } finally {
      if (mounted) setState(() { _transferring = false; _cancelTransfer = false; });
    }
  }

  bool _matches(String mime) => _filter == 'all' ||
      (_filter == 'images' && mime.startsWith('image/')) ||
      (_filter == 'videos' && mime.startsWith('video/'));

  bool _isImage(File file) => RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false)
      .hasMatch(file.path);

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(0)} KB';

  void _previewRemote(McrpMediaItem item) {
    final client = _client;
    if (client == null) return;
    final uri = client.address.mediaFile(item.id);
    _preview(name: item.name, imageUrl: item.mime.startsWith('image/') ? uri.toString() : null,
        videoUrl: item.mime.startsWith('video/') ? uri : null);
  }

  void _previewLocal(File file) {
    _preview(name: file.uri.pathSegments.last,
        imageFile: _isImage(file) ? file : null,
        videoUrl: !_isImage(file) ? file.uri : null);
  }

  void _preview({required String name, String? imageUrl, File? imageFile, Uri? videoUrl}) {
    showDialog<void>(context: context, builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Fechar',
              onPressed: () => Navigator.of(ctx).pop())),
          Flexible(child: AspectRatio(aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black,
              child: imageFile != null
                  ? Image.file(imageFile, fit: BoxFit.contain)
                  : imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(child: Text('Foto indisponível.')))
                      : videoUrl != null
                          ? _GalleryVideoPlayer(key: ValueKey(videoUrl.toString()), url: videoUrl)
                          : const Center(child: Text('Prévia não disponível.')),
            ),
          )),
          const SizedBox(height: 12),
        ]),
      ),
    ));
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CELULAR SELECIONADO', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.smartphone_rounded, size: 27),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_deviceName, style: theme.textTheme.titleLarge,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_client == null ? 'Desconectado' : 'Conexão privada MCRP · Wi-Fi local',
                  style: theme.textTheme.bodySmall),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _transferring ? null : _chooseDevice,
              icon: const Icon(Icons.devices), label: const Text('Aparelhos'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: _transferring ? null : _refresh,
              icon: const Icon(Icons.refresh), label: const Text('Atualizar'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _transferring ? null : () => _addDevice(),
              icon: const Icon(Icons.add_link), label: const Text('Endereço'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: _transferring ? null : _scanQr,
              icon: const Icon(Icons.qr_code_scanner), label: const Text('Ler QR'))),
          ]),
        ],
      )),
    );
  }

  Widget _remoteRow(McrpMediaItem item) {
    final selected = _selected.contains(item.id);
    final isPhoto = item.mime.startsWith('image/');
    final uri = _client?.address.mediaFile(item.id).toString();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: SizedBox(width: 58, height: 58,
          child: ClipRRect(borderRadius: BorderRadius.circular(9), child:
            isPhoto && uri != null
                ? Image.network(uri, fit: BoxFit.cover, cacheWidth: 150,
                    errorBuilder: (_, _, _) => const Icon(Icons.image_outlined))
                : const Icon(Icons.movie_outlined, size: 34))),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${isPhoto ? 'Foto' : 'Vídeo'} · ${_size(item.size)}'),
        onTap: () => _previewRemote(item),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Baixar cópia', onPressed: _transferring ? null : () => _download([item]),
            icon: const Icon(Icons.download_outlined)),
          Checkbox(value: selected, onChanged: _transferring ? null : (checked) {
            setState(() { if (checked == true) { _selected.add(item.id); } else { _selected.remove(item.id); } });
          }),
        ]),
      ),
    );
  }

  Widget _localRow(File file) {
    final isPhoto = _isImage(file);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: SizedBox(width: 58, height: 58,
          child: ClipRRect(borderRadius: BorderRadius.circular(9), child: isPhoto
              ? Image.file(file, fit: BoxFit.cover, cacheWidth: 150)
              : const Icon(Icons.movie_outlined, size: 34))),
        title: Text(file.uri.pathSegments.last.replaceFirst(RegExp(r'^vr_[0-9a-f]{16}_'), ''),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${isPhoto ? 'Foto' : 'Vídeo'} · ${_size(file.lengthSync())}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _previewLocal(file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _remoteItems.where((item) => _matches(item.mime)).toList();
    final files = _localFiles.where((file) => _matches(_isImage(file) ? 'image/jpeg' : 'video/mp4')).toList();
    return AdaptiveMainScaffold(
      currentIndex: 4,
      onDestinationSelected: (index) => navigateToMainDestination(context, index, currentIndex: 4),
      appBar: AppBar(title: const Text('Galeria remota')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: _header(context)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              Expanded(child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<bool>(value: true, icon: Icon(Icons.wifi), label: Text('No A3')),
                  ButtonSegment<bool>(value: false, icon: Icon(Icons.download_done), label: Text('Recebidos')),
                ],
                selected: {_remoteTab},
                onSelectionChanged: (values) => setState(() => _remoteTab = values.first),
              )),
            ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              for (final item in const [('all', 'Tudo'), ('images', 'Fotos'), ('videos', 'Vídeos')])
                Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
                  label: Text(item.$2),
                  selected: _filter == item.$1,
                  onSelected: (_) => setState(() => _filter = item.$1),
                )),
              const Spacer(),
              if (_remoteTab) Text('${items.length} mídia(s)', style: Theme.of(context).textTheme.labelSmall),
            ])),
          if (_loading) const LinearProgressIndicator(),
          if (_transferring) Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text('Transferindo ${_completed + 1} de $_total')),
                TextButton(onPressed: () => setState(() => _cancelTransfer = true),
                  child: const Text('Cancelar')),
              ]),
              LinearProgressIndicator(value: _expected > 0 ? _received / _expected : null),
            ])),
          if (_error != null) Padding(padding: const EdgeInsets.all(10),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            itemCount: _remoteTab ? items.isEmpty ? 1 : items.length : files.isEmpty ? 1 : files.length,
            itemBuilder: (context, index) {
              if (_remoteTab) {
                if (items.isEmpty) return const Padding(padding: EdgeInsets.all(24),
                    child: Text('Nenhum arquivo remoto. Conecte o A3 e toque em Atualizar.'));
                return _remoteRow(items[index]);
              }
              if (files.isEmpty) return const Padding(padding: EdgeInsets.all(24),
                  child: Text('Nenhum arquivo recebido. Baixe fotos ou vídeos do A3.'));
              return _localRow(files[index]);
            },
          )),
          if (_remoteTab && _selected.isNotEmpty) SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: _transferring ? null : () => _download(_remoteItems.where((i) => _selected.contains(i.id)).toList()),
                icon: const Icon(Icons.file_download_outlined),
                label: Text('Baixar selecionados (${_selected.length})'),
              )),
              IconButton(tooltip: 'Limpar seleção', onPressed: _transferring ? null : () => setState(_selected.clear),
                icon: const Icon(Icons.clear_all)),
            ]),
          )),
        ]),
      ))),
    );
  }
}

class _GalleryQrScanner extends StatefulWidget {
  const _GalleryQrScanner();
  @override
  State<_GalleryQrScanner> createState() => _GalleryQrScannerState();
}

class _GalleryQrScannerState extends State<_GalleryQrScanner> {
  final scanner = MobileScannerController();
  bool done = false;
  @override
  void dispose() { unawaited(scanner.dispose()); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ler QR do transmissor')),
    body: MobileScanner(controller: scanner, onDetect: (capture) {
      if (done) return;
      for (final code in capture.barcodes) {
        final value = code.rawValue;
        if (value == null) continue;
        try { McrpAddress.parse(value); } on FormatException { continue; }
        done = true;
        Navigator.of(context).pop(value);
        return;
      }
    }),
  );
}

class _GalleryVideoPlayer extends StatefulWidget {
  const _GalleryVideoPlayer({super.key, required this.url});
  final Uri url;
  @override
  State<_GalleryVideoPlayer> createState() => _GalleryVideoPlayerState();
}

class _GalleryVideoPlayerState extends State<_GalleryVideoPlayer> {
  late final VlcPlayerController controller;
  @override
  void initState() {
    super.initState();
    controller = VlcPlayerController(
      mediaSource: VlcMediaSource(uri: widget.url, mediaOptions: const [':network-caching=300']),
      autoPlay: true,
      options: const [],
    );
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => VlcPlayer(controller: controller, fit: VlcVideoFit.contain);
}
