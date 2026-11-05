import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.339', build: 339);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.339', build: 339),
      changes: <String>[
        'Transporte RTSP automático UDP/TCP, com confirmação de primeiro quadro.',
        'Preferência por câmera memorizada após reprodução confirmada.',
        'Seleção manual UDP ou TCP e diagnósticos de reconexão.',
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
