import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.350', build: 350);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.350', build: 350),
      changes: <String>[
        'Corrigido o aviso da análise estática do APK 294 na leitura de bateria do mapa.',
        'Verificação de telemetria conserva a condição anterior e evita redesenhos desnecessários.',
        'Novo teste preventivo detecta a ausência de chaves no retorno condicional.',
        'Mapas, GPS, câmera, gravação e rotas permanecem sem alterações funcionais.',
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
