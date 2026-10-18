import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.285', build: 285);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.285', build: 285),
      changes: <String>[
        'Planejamento com assistente em etapas para criar rotas.',
        'Comece a viagem pela localização atual ou escolha cidades.',
        'Veja o mapa da viagem e salve ou exporte seus roteiros.',
        'Exporte em GPX ou JSON e consulte viagens salvas offline.',
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
