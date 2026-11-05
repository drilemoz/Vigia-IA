import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.352', build: 352);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.352', build: 352),
      changes: <String>[
        'Serviços e APIs agora permite consultar as chaves cadastradas com Mostrar/Ocultar e Copiar.',
        'Chaves de APIs podem ser exportadas e importadas em arquivo .env legível, sem senha.',
        'Colar, Copiar e Verificar configuração do Google Maps ficam na mesma linha.',
        'Backups antigos protegidos continuam importáveis; RTSP e mapas preservados.',
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
