import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.343', build: 343);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.343', build: 343),
      changes: <String>[
        'Corrigidos dois avisos de lint do Flutter que impediam o APK 288 de avançar à compilação.',
        'A abertura inicial de rota salva agora utiliza bloco if explícito, sem alterar seu comportamento.',
        'Rota de bicicleta opcional agora usa elemento anulável; planejamento unificado e mapas offline preservados.',
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
