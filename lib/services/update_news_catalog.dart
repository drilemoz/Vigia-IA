import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versao instalada aparece no popup Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.334', build: 334);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.334', build: 334),
      changes: <String>[
        'Serviços e APIs: exportação e importação de chaves protegidas por senha em arquivo portável.',
        'Pesquisa de cidades e pontos próximos: tempos máximos de resposta e alternativa local.',
        'Mapa: faixa superior compacta com atalho Explorar junto de Vigia IA, Perto, Região e Rota.',
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
