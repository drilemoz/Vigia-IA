import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.365', build: 365);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.365', build: 365),
      changes: <String>[
        'GPS: leituras antigas são distinguidas de localização desligada ou permissão negada.',
        'No Android, mapa visível solicita posição moderada mesmo sem deslocamento.',
        'Pontos: consultas online com fallback e mensagens claras; busca pelo centro do mapa sem GPS.',
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
