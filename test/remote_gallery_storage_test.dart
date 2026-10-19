import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/mcrp_client.dart';
import 'package:vigiaia/services/remote_gallery_storage.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';
  final address = McrpAddress.parse('http://192.168.43.1:8765/live/$token');

  test('nome local é determinístico, não inclui segredo nem traversal', () {
    const item = McrpMediaItem(id: 'p_123', name: '../../Carro.jpg',
        mime: 'image/jpeg', size: 3000, modified: 1234);
    final name = RemoteGalleryStorage.fileName(address, item);
    expect(name, startsWith('vr_'));
    expect(name, endsWith('Carro.jpg'));
    expect(name, isNot(contains(token)));
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('..')));
    expect(RemoteGalleryStorage.fileName(address, item), name);
  });

  test('aceita apenas fotos e vídeos com tamanho e ID válidos', () {
    expect(RemoteGalleryStorage.supported(const McrpMediaItem(
        id: 'p_1', name: 'foto.jpg', mime: 'image/jpeg', size: 123, modified: 1)), isTrue);
    expect(RemoteGalleryStorage.supported(const McrpMediaItem(
        id: 'v_1', name: 'video.mp4', mime: 'video/mp4', size: 123, modified: 1)), isTrue);
    expect(RemoteGalleryStorage.supported(const McrpMediaItem(
        id: '../x', name: 'foto.jpg', mime: 'image/jpeg', size: 123, modified: 1)), isFalse);
    expect(RemoteGalleryStorage.supported(const McrpMediaItem(
        id: 'x', name: 'arquivo.zip', mime: 'application/zip', size: 123, modified: 1)), isFalse);
    expect(RemoteGalleryStorage.supported(const McrpMediaItem(
        id: 'x', name: 'foto.jpg', mime: 'image/jpeg', size: 0, modified: 1)), isFalse);
  });

  test('lista só cópias privadas concluídas, detecta duplicatas e limpa parcial', () async {
    final temp = await Directory.systemTemp.createTemp('vigia-gallery-test-');
    addTearDown(() async { if (await temp.exists()) await temp.delete(recursive: true); });
    final storage = RemoteGalleryStorage(directoryProvider: () async => temp);
    const item = McrpMediaItem(id: 'p_1', name: 'captura.jpg',
        mime: 'image/jpeg', size: 6, modified: 100);
    final folder = await storage.directory();
    final name = RemoteGalleryStorage.fileName(address, item);
    final good = File('${folder.path}/$name');
    await good.writeAsBytes([1, 2, 3, 4, 5, 6]);
    await File('${folder.path}/$name.part').writeAsBytes([1, 2]);
    await File('${folder.path}/anotacoes.txt').writeAsString('não indexar');
    expect((await storage.savedFiles()).map((e) => e.path), [good.path]);
    expect((await storage.localCopy(address, item))?.path, good.path);
    await good.writeAsBytes([1, 2]);
    expect(await storage.localCopy(address, item), isNull);
    expect(await good.exists(), isFalse);
  });
}
