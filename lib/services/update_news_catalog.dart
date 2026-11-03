import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versao instalada aparece no popup Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.336', build: 336);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.336', build: 336),
      changes: <String>[
        'APK 281: corrigida análise estática Flutter para compilar mapas, rotas e backup de APIs.',
        'Preservados Geoapify, OpenRouteService, previsão Open-Meteo de 48 horas e mapa offline.',
        'Correções de nulidade, blocos if e imports sem alterar funcionalidades existentes.',
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
