import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.384', build: 384);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.384', build: 384),
      changes: <String>[
        'Corrigido o teste Flutter da comparação de rotas para validar o nome do provedor.',
        'Preservados os nomes das APIs, as distâncias, os tempos estimados e a seleção de alternativas.',
        'Mantidas as verificações do YOLO26s offline e do Flutter Analyze.',
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
