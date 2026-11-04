import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.345', build: 345);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.345', build: 345),
      changes: <String>[
        'Diagnósticos de encerramento agora distinguem falhas graves de limpeza de memória em segundo plano.',
        'Relatórios identificam a versão original e correlacionam o encerramento ao processo Android correto.',
        'Uma falha temporária na leitura do diagnóstico pode ser recuperada ao voltar para o aplicativo.',
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
