import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.368', build: 368);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.368', build: 368),
      changes: <String>[
        'Próximos pontos abre com mais altura para visualizar resultados e avisos confortavelmente.',
        'Maior espaço para estados vazios ou erros sem alterar busca, filtros ou GPS.',
        'Os controles e o funcionamento offline permanecem inalterados.',
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
