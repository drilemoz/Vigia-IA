import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.353', build: 353);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.353', build: 353),
      changes: <String>[
        'APK 300: corrigidos verificadores preventivos que ainda exigiam a versão 1.0.351.',
        'Contratos de release passam a ler a versão atual, evitando bloqueios após atualizações.',
        'Central de APIs, exportação .env, RTSP automático e mapas preservados.',
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
