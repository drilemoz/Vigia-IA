import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.374', build: 374);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.374', build: 374),
      changes: <String>[
        'Assistente de viagem agora tem três etapas: destino, programação e ritmo.',
        'Data, hora, pausas e limite de chegada são escolhidos antes do ritmo.',
        'Nova meta em quilômetros no primeiro dia ou em toda a viagem, com cálculo real das etapas.',
        'Resumo inclui previsão de data e hora de chegada; avisos de segurança continuam ativos.',
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
