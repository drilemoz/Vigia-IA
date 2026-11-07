import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.363', build: 363);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.363', build: 363),
      changes: <String>[
        'Conferência de preparação offline sob demanda no Planejamento, sem GPS nem internet.',
        'Avisa sobre arquivos MBTiles ausentes, trechos fora dos limites declarados e apoios locais encontrados.',
        'Mostra pernoites e paradas ainda não verificados; não confunde cobertura estimada com tiles testados.', 
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
