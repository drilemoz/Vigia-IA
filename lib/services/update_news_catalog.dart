import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.351', build: 351);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.351', build: 351),
      changes: <String>[
        'Base 1.0.350 restaurada: preservados mapas, GPS, cicloviagem e diagnósticos.',
        'Câmeras RTSP agora escolhem UDP ou TCP automaticamente quando não chega vídeo.',
        'Transporte funcional memorizado por câmera; opções manuais UDP e TCP disponíveis.',
        'Prévia Media3 permanece separada; corrigido o seletor para Flutter atual.',
      ],
    ),
  ]);

  UpdateRelease? releaseFor(AppBuildVersion installed) {
    for (final release in releases) {
      if (release.version == installed) return release;
    }
    return null;
  }
}
