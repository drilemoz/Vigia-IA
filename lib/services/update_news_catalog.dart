import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.314', build: 314);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.314', build: 314),
      changes: <String>[
        'Diagnóstico automático em todos os modos, sem precisar iniciar a coleta.',
        'Ao reabrir após uma falha detectada, o app oferece exportar o relatório salvo.',
        'Histórico de desempenho, erros gerais e transmissão, com proteção de credenciais.',
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
