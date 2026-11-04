import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/retained_mbtiles_tile_provider.dart';

void main() {
  test('pacote sem leitores pode ser excluido sem abrir SQLite', () async {
    final directory = await Directory.systemTemp.createTemp('vigia-mbtiles-');
    try {
      final file = File('${directory.path}/removido.mbtiles');
      await file.writeAsBytes(const <int>[1, 2, 3, 4]);
      expect(await file.exists(), isTrue);
      await RetainedMbTilesTileProvider.deleteWhenUnused(file.path);
      expect(await file.exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
