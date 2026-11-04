import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.338', build: 338);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.338', build: 338),
      changes: <String>[
        'Modo Offline agora usa apenas MBTiles, mesmo com Google Maps configurado.',
        'Cobertura offline verificada na área visualizada e avisos quando faltam mapas.',
        'Downloads mais resistentes, cancelamento de rede e atualização sem apagar a cópia anterior.',
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
