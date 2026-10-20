import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.313', build: 313);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.313', build: 313),
      changes: <String>[
        'Gravação independente da compressão de rede, com menos cópias de imagem no A3.',
        'Transmissão durante REC respeita o FPS escolhido, mantendo a proteção térmica.',
        'H.264 recupera a sequência após atrasos; disponíveis opções de 15, 24 e 30 FPS.',
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
