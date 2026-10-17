import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.272', build: 272);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.272', build: 272),
      changes: <String>[
        'Ao vivo ganhou controles MCRP do Redmi A3, sem sair do monitoramento.',
        'Zoom, lanterna, gravação, foto, FPS, resolução e Eco via Wi-Fi local.',
        'Tela Minha Câmera agora reutiliza o painel visual de comandos remotos.'
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
