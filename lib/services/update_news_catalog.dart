import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.358', build: 358);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.358', build: 358),
      changes: <String>[
        'Corrigido aviso fatal no Flutter Analyze da busca de cidades ao longo da rota (workflow APK 305).',
        'Mantidos itinerário de cidades em ordem, pacotes de pontos offline e mapa MBTiles no Planejamento.',
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
