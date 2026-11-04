import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.347', build: 347);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.347', build: 347),
      changes: <String>[
        'Visual do mapa com listas compactas para Aparência, Provedor e Base.',
        'Escolhas são confirmadas no botão OK; Cancelar mantém o mapa anterior.',
        'A configuração de Serviços e APIs fica apenas na central de Configurações.',
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
