import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.382', build: 382);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.382', build: 382),
      changes: <String>[
        'Corrigidos os dois avisos fatais de blocos if no Flutter Analyze do build Android 326.',
        'Preservadas as regras de pernoite e seleção de rotas em modo chuva.',
        'Adicionados testes de regressão para os blocos corrigidos.',
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
