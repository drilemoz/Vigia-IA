import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.337', build: 337);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.337', build: 337),
      changes: <String>[
        'Navegação com instruções e avisos em português brasileiro.',
        'Painel compacto como padrão, com detalhes expandidos quando necessário.',
        'GPS desatualizado pausa as orientações; traçado mais fino e menos controles repetidos.',
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
