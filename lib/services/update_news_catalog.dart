import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.372', build: 372);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.372', build: 372),
      changes: <String>[
        'Corrigido o aviso de análise estática do Flutter no descarte de uma rota não salva.',
        'Mantidos o planejamento compacto por dias e as conferências offline.',
        'Verificação preventiva do projeto aprovada no build Android APK 317.',
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
