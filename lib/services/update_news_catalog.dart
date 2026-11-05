import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.341', build: 341);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.341', build: 341),
      changes: <String>[
        'APK 297: corrigido o parâmetro incompatível na prévia RTSP Media3.',
        'Atualizado seletor de transporte para Flutter 3.44 sem aviso fatal.',
        'RTSP automático UDP/TCP, mapas e demais recursos preservados.',
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
