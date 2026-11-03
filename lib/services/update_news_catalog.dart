import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versao instalada aparece no popup Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.333', build: 333);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.333', build: 333),
      changes: <String>[
        'Google Maps: o APK pode incluir uma chave opcional configurada no GitHub Secret MAPS_API_KEY.',
        'A central diferencia chave salva no aparelho de Maps SDK habilitado no APK.',
        'Sem chave no APK, o mapa Google permanece bloqueado e o OpenStreetMap/offline funciona normalmente.',
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
