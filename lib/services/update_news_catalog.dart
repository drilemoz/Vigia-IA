import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.375', build: 375);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.375', build: 375),
      changes: <String>[
        'Planejamento: paradas não podem gerar dias com distância negativa.',
        'Metas de quilômetros agora conferem limite diário e horário com pausas.',
        'Calendário, pesquisa de cidades e opção do mapa online corrigidos.',
        'Cancelar Nova rota preserva as escolhas e o planejamento anteriores.',
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
