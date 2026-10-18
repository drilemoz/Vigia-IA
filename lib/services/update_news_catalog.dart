import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.289', build: 289);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.289', build: 289),
      changes: <String>[
        'Escanear rede combina ONVIF, Vigia IA e busca TCP por IP no Wi-Fi.',
        'Identifica RTSP confirmado e portas TCP ainda nao verificadas.',
        'Lista mostra progresso, estado da rede e dispositivos deduplicados.',
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
