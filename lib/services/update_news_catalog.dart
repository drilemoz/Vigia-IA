import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.377', build: 377);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.377', build: 377),
      changes: <String>[
        'GPS: aquisição de alta precisão, limite de espera e reconexão.',
        'Preferências de pavimento compartilhadas entre Mapas e Planejamento.',
        'OpenRouteService migrado ao novo endpoint HeiGIT e alternativas com dados de superfície.',
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
