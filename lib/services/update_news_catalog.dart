import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.369', build: 369);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.369', build: 369),
      changes: <String>[
        'Atualizações do GitHub agora detectam Releases novas mesmo se o APK universal não puder ser baixado internamente.',
        'O aviso não declara mais que o app está atualizado quando há versão mais recente publicada.',
        'Limite de tamanho para APK universal ampliado, mantendo SHA-256, assinatura e instalação manual.',
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
