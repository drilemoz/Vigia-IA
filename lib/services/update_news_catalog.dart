import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.383', build: 383);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.383', build: 383),
      changes: <String>[
        'Corrigida a incompatibilidade do Python na preparação do modelo YOLO26s offline.',
        'O GitHub Actions utiliza Python 3.12 para a exportação e validação do modelo.',
        'Preservadas as validações do modelo real e as integrações de mapas e GPS.',
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
