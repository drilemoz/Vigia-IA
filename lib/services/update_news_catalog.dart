import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.366', build: 366);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.366', build: 366),
      changes: <String>[
        'Corrigido aviso do Flutter Analyze no serviço GPS para permitir o próximo build Android.',
        'Mantidas as atualizações moderadas de GPS, consulta pelo centro do mapa e pontos offline.',
        'Sem alteração nas permissões nem no rastreamento de trajetos; nova regressão preventiva.',
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
