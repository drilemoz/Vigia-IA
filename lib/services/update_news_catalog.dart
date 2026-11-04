import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.344', build: 344);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.344', build: 344),
      changes: <String>[
        'Corrigido o teste da prévia de bicicleta que bloqueava o APK 289 após a unificação do planejamento.',
        'O planejamento pode ser aberto antes de calcular as etapas; teste verifica o botão e a ação.',
        'Mantidos mapas, navegação, biblioteca e preferências compartilhadas de cicloviagem.',
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
