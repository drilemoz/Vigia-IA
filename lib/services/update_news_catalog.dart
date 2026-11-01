import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.328', build: 328);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.328', build: 328),
      changes: <String>[
        'Configurações agora concentra as seis APIs em uma única entrada, sem duplicar Gemini e Google Maps.',
        'Atalhos de APIs no painel do mapa e na busca Gemini levam à mesma central.',
        'Chaves, ajuda, testes e serviços existentes foram preservados.',
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
