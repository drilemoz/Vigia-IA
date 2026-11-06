import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.354', build: 354);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.354', build: 354),
      changes: <String>[
        'Pacotes de pontos offline agora podem ser abertos sem GPS, com marcadores e distâncias não inventadas.',
        'Falhas de consulta de uma região tentam pontos locais sem apagar os salvos.',
        'Planejamento abre MBTiles existentes, permite escolher o mapa e exibe pontos de apoio offline junto da rota.',
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
