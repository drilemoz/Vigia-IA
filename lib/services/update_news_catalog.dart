import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.340', build: 340);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.340', build: 340),
      changes: <String>[
        'Verificação preventiva de Novidades corrigida para aceitar textos atualizados da versão.',
        'Mensagens vazias e provisórias são rejeitadas nos testes de validação do catálogo.',
        'Mantidas as melhorias de mapas offline e do mapa 3D da versão anterior.',
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
