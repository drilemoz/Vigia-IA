import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.308', build: 308);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.308', build: 308),
      changes: <String>[
        'Corrigidos os 8 alertas do Flutter Analyze que bloquearam o APK 258.',
        'Histórico de veículos com atualização segura ao salvar uma placa.',
        'Galeria Remota e fotos do A3 preservadas sem mudar o fluxo de transmissão.',
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
