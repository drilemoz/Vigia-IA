import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.326', build: 326);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.326', build: 326),
      changes: <String>[
        'Configuração inicial: após as permissões, serviços e APIs opcionais Gemini, Google Maps e Stadia Maps.',
        'Como obter as três chaves e acesso aos controles existentes de salvar, testar e remover.',
        'Assistente retoma a etapa de APIs após interrupção e não reaparece a cada atualização.',

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
