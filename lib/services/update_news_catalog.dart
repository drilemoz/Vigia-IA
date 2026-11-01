import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.324', build: 324);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.324', build: 324),
      changes: <String>[
        'Pesquisa por nome no Planejamento aceita cidades retornadas como limites administrativos; busca online explícita e seleção orientada.',
        'Diálogo de ritmo mais compacto, com saída, pausas e almoço organizados em duas linhas.',
        'Mapa ocupa a área superior com cabeçalho integrado; prévia limitada em altura e GPS distingue velocidade de direção.',
        'Tempos da prévia e plano diário usam arredondamento compatível.',
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
