import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.339', build: 339);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.339', build: 339),
      changes: <String>[
        'Mapas MBTiles com fechamento protegido durante troca de pacotes e navegação.',
        'Exclusão de pacotes aguarda liberação do SQLite para evitar erros na interface.',
        'Renderizador 3D Android ajustado para evitar inicializações sobrepostas.',
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
