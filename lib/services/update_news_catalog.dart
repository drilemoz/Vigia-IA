import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.364', build: 364);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.364', build: 364),
      changes: <String>[
        'Corrigido aviso fatal do Flutter Analyze no texto de nota offline da conferência de paradas.',
        'Preservados mapas offline, preparação da viagem, pontos salvos e conferências locais.',
        'Atualizados testes preventivos e metadados para o APK 309.',
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
