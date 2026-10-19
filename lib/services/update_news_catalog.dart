import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.300', build: 300);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.300', build: 300),
      changes: <String>[
        'Corrigida a verificação preventiva que bloqueava o APK 251.',
        'Teste de versão acompanha o build atual, sem valores antigos fixos.',
        'Controles do transmissor verificam prontidão sem acesso nulo redundante.',
        'Mantidas busca RTSP, reprodução e opções de transporte da versão anterior.',
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
