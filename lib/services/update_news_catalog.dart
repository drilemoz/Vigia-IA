import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.301', build: 301);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.301', build: 301),
      changes: <String>[
        'Melhoradas as verificações de atualização para evitar bloqueios incorretos na geração do aplicativo.',
        'O catálogo de Novidades agora aceita informações sobre correções e melhorias de estabilidade.',
        'Preservados o cadastro RTSP assistido, a transmissão e os cronômetros do Ao vivo.',
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
