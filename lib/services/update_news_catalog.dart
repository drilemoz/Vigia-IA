import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.299', build: 299);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.299', build: 299),
      changes: <String>[
        'Conecte câmeras RTSP com busca no Wi-Fi e preenchimento de endereço.',
        'Selecione caminhos conhecidos ou deixe o aplicativo procurar o stream.',
        'Confira acesso, autenticação e vídeo antes de abrir a câmera.',
        'Escolha o transporte TCP ou o padrão do reprodutor para cada câmera.',
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
