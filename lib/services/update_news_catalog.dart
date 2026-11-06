import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.359', build: 359);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.359', build: 359),
      changes: <String>[
        'Planejamento preserva altitudes e totais de subida/descida nas rotas salvas para consulta offline.',
        'Exibe relevo por etapa quando o provedor fornece perfil completo ou parcial de altitudes.',
        'Consulta manual de clima por dia usando a data escolhida, com amostras salvas e avisos de desatualização.',
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
