import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.349', build: 349);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.349', build: 349),
      changes: <String>[
        'Temporizador do HUD e sensor de bússola agora param quando o mapa fica oculto ou o aplicativo sai do primeiro plano.',
        'Leituras iguais de bateria e rádio não provocam reconstruções desnecessárias da interface.',
        'Identificação de fontes de câmera e decisões do HUD isoladas em políticas com testes de regressão.',
        'Rotas, gravação e monitoramento preservados sem ativar câmeras ou IA em segundo plano.',
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
