import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.323', build: 323);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.323', build: 323),
      changes: <String>[
        'Ajuste de velocidade e horas pedaladas por dia disponível durante a navegação de bicicleta.',
        'ETA e planejamento por dias são recalculados sem parar a rota em andamento.',
        'Registro diagnóstico das ações de edição e aplicação do ritmo durante a navegação.',
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
