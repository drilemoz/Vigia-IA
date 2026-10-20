import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.316', build: 316);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.316', build: 316),
      changes: <String>[
        'Corrigida a espera dos testes Flutter do aviso de recuperação.',
        'Exportação e manutenção de incidentes verificadas sem espera infinita.',
        'Nenhuma alteração no comportamento do diagnóstico no aplicativo.',
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
