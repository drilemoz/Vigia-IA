import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.381', build: 381);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.381', build: 381),
      changes: <String>[
        'Corrigida a verificação preventiva da prévia de rotas que bloqueava o build Android 325.',
        'Preservados os avisos de pavimento, relevo e segurança para cicloviagens.',
        'Sincronizados os contratos e metadados da versão sem desativar testes.',
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
