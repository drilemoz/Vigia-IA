import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.371', build: 371);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.371', build: 371),
      changes: <String>[
        'Corrigida a verificação preventiva da prévia de rotas após a reorganização do planejamento.',
        'Aviso completo de acesso seguro, água e hospedagem restaurado no painel de apoios.',
        'Planejamento por slides, mapa e ferramentas recolhíveis preservados.',
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
