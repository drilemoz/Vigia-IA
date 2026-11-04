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
        'Planejamento de cicloviagem unificado entre Início e Mapas, com o mesmo editor e biblioteca.',
        'Rota já calculada no mapa abre no planejador sem refazer consultas, com horários e pausas compartilhados.',
        'Rotas anteriores continuam disponíveis; salvar em Mapas alimenta a biblioteca de viagens.',
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
