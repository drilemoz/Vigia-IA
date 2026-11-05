import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';

/// Gerencia o ciclo de vida de MBTiles usados por um TileLayer.
///
/// O TileLayer pode ser destruido antes de um ImageProvider terminar de ler
/// seu tile. Fechar SQLite no mesmo frame provoca "database has already been
/// closed" em callbacks assíncronos de decodificacao. A camada chama
/// [dispose], mas o dono (tela) deve chamar [release] apenas quando trocar o
/// pacote ou encerrar a tela. A conexao antiga e mantida por um prazo de
/// drenagem, sem permitir novas solicitacoes do widget que foi removido.
///
/// Arquivos excluidos do catalogo tambem aguardam o fechamento de todas as
/// conexoes abertas neste processo. Na proxima inicializacao, o servico de
/// mapas remove arquivos MBTiles que nao constem mais do catalogo, cobrindo
/// um encerramento forçado durante essa drenagem.
class RetainedMbTilesTileProvider extends TileProvider {
  RetainedMbTilesTileProvider._(this.path, this._delegate) {
    _openByPath.putIfAbsent(path, () => <RetainedMbTilesTileProvider>{}).add(this);
  }

  factory RetainedMbTilesTileProvider.fromPath({required String path}) {
    final delegate = MbTilesTileProvider.fromPath(path: path);
    return RetainedMbTilesTileProvider._(path, delegate);
  }

  static const Duration retirementGrace = Duration(seconds: 45);
  static final Map<String, Set<RetainedMbTilesTileProvider>> _openByPath = {};
  static final Set<String> _pendingDeletes = <String>{};

  final String path;
  final MbTilesTileProvider _delegate;
  MbTilesTileProvider get delegate => _delegate;
  Timer? _retirementTimer;
  bool _released = false;
  bool _closed = false;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // Um TileLayer montado nunca solicita tiles de uma conexao fechada.
    // ImageProviders ja criados ficam protegidos pelo periodo de drenagem.
    return _delegate.getImage(coordinates, options);
  }

  @override
  void dispose() {
    // flutter_map chama isto ao desmontar o TileLayer, possivelmente antes
    // de decodificacoes pendentes. Apenas a tela proprietaria chama release().
  }

  /// Libera a referencia da tela sem interromper leituras disparadas antes
  /// do ultimo rebuild. Idempotente mesmo que flutter_map chame dispose().
  void release() {
    if (_released) return;
    _released = true;
    _retirementTimer = Timer(retirementGrace, _close);
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _retirementTimer?.cancel();
    _retirementTimer = null;
    try {
      _delegate.dispose();
    } finally {
      final open = _openByPath[path];
      open?.remove(this);
      if (open != null && open.isEmpty) _openByPath.remove(path);
      unawaited(_deleteIfUnused(path));
    }
  }

  /// Retira o arquivo do armazenamento somente depois de todas as telas
  /// deixarem de usa-lo. A exclusao logica do catalogo ocorre antes, no
  /// OfflineMapService, para que as telas liberem seus provedores.
  static Future<void> deleteWhenUnused(String path) async {
    _pendingDeletes.add(path);
    await _deleteIfUnused(path);
  }

  static Future<void> _deleteIfUnused(String path) async {
    if (!_pendingDeletes.contains(path) ||
        (_openByPath[path]?.isNotEmpty ?? false)) {
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      _pendingDeletes.remove(path);
    } on FileSystemException {
      // Nao descartar a intencao de excluir se o SO ainda mantiver o arquivo.
      // Arquivos fora do catalogo serao revistos na proxima inicializacao.
    }
  }
}
