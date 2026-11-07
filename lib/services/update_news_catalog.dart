import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.367', build: 367);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.367', build: 367),
      changes: <String>[
        'Atualizações pelo GitHub Releases em Sobre, com verificação ao abrir ou retomar o aplicativo.',
        'Download manual de APK universal com progresso e validação SHA-256.',
        'Instalação pelo Android somente após verificar pacote, versão e assinatura.',
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
