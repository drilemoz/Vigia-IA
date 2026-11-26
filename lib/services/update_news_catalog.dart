import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.379', build: 379);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.379', build: 379),
      changes: <String>[
        'Geoapify: endereço aproximado ao selecionar ponto no mapa, com fallback Nominatim e cache temporário.',
        'Mapas: consulta manual complementa categorias ausentes via Geoapify; economia de dados preservada.',
        'Mais detalhes de água, banheiros, estacionamentos e campings; origem dos pontos preservada ao atualizar GPS.',
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
