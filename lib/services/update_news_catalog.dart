import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versao instalada aparece no popup Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.335', build: 335);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.335', build: 335),
      changes: <String>[
        'Geoapify participa da busca e complementa pontos próximos quando o OSM falha.',
        'OpenRouteService opcional para rotas ciclísticas, com retorno ao Valhalla.',
        'Open-Meteo: até 48 h de previsão, índice UV, radiação solar e clima da rota sob demanda.',
        'Buscar pontos na cidade selecionada sem mudar o GPS; configurar até dois atalhos rápidos no mapa.',
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
