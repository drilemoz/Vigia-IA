import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.370', build: 370);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.370', build: 370),
      changes: <String>[
        'Planejamento com resumo de rota e cartões individuais para cada dia da cicloviagem.',
        'Botões Anterior e Próximo dia, toque nos indicadores e gesto lateral para mudar de etapa.',
        'Mapa e ferramentas de clima, apoios e preparação offline organizados em painéis recolhíveis.',
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
