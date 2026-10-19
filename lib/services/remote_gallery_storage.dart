import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'mcrp_client.dart';

/// Cópias privadas recebidas de transmissores MCRP. A chave de pareamento não
/// aparece em nomes de arquivos, registros de mídia ou mensagens visíveis.
class RemoteGalleryStorage {
  const RemoteGalleryStorage({this.directoryProvider});

  final Future<Directory> Function()? directoryProvider;

  Future<Directory> directory() async {
    final base = await (directoryProvider?.call() ?? getApplicationDocumentsDirectory());
    final folder = Directory('${base.path}/GaleriaRemota');
    await folder.create(recursive: true);
    return folder;
  }

  static bool supported(McrpMediaItem item) =>
      (item.mime.startsWith('image/') || item.mime.startsWith('video/')) &&
      item.size > 0 && item.size <= 2 * 1024 * 1024 * 1024 &&
      RegExp(r'^[A-Za-z0-9._-]{1,180}$').hasMatch(item.id);

  static String fileName(McrpAddress address, McrpMediaItem item) {
    final identity = '${address.liveUrl.host}:${address.liveUrl.port}|'
        '${item.id}|${item.size}|${item.modified}';
    final hash = sha256.convert(identity.codeUnits).toString().substring(0, 16);
    var safeName = item.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    safeName = safeName.replaceAll(RegExp(r'^\.+'), '').replaceAll('..', '_');
    if (safeName.isEmpty) safeName = 'arquivo.bin';
    if (safeName.length > 90) safeName = safeName.substring(safeName.length - 90);
    return 'vr_${hash}_$safeName';
  }

  Future<List<File>> savedFiles() async {
    final folder = await directory();
    final files = <File>[];
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('vr_') || name.endsWith('.part')) continue;
      if (await entity.length() == 0) continue;
      files.add(entity);
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<File?> localCopy(McrpAddress address, McrpMediaItem item) async {
    final file = File('${(await directory()).path}/${fileName(address, item)}');
    if (!await file.exists()) return null;
    if (await file.length() == item.size) return file;
    await file.delete();
    return null;
  }

  Future<({File file, bool alreadySaved})> receive(
    McrpClient client,
    McrpMediaItem item, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!supported(item)) throw const FormatException('Mídia remota não suportada.');
    final previous = await localCopy(client.address, item);
    if (previous != null) return (file: previous, alreadySaved: true);
    final folder = await directory();
    final file = await client.download(item, folder,
        targetName: fileName(client.address, item),
        onProgress: onProgress, isCancelled: isCancelled);
    return (file: file, alreadySaved: false);
  }
}
