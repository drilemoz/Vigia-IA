import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.356', build: 356);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.356', build: 356),
      changes: <String>[
        'Corrigidos dois avisos fatais do Flutter Analyze no Planejamento offline (APK 303), sem alterar os cálculos.',
        'Mantidos mapas MBTiles, seleção de pacotes e pontos salvos offline das versões anteriores.',
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
