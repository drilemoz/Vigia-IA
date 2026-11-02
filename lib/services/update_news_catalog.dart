import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.330', build: 330);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.330', build: 330),
      changes: <String>[
        'O Vigia IA agora recebe H.264 do Minha Câmera pelo fluxo privado HTTP Annex-B, além de MJPEG.',
        'O monitor e a câmera remota alternam automaticamente de codec e podem analisar quadros H.264 com a IA.',
        'O watchdog RTSP observa a ausência prolongada de quadros capturados, mesmo com VLC em reprodução.',
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
