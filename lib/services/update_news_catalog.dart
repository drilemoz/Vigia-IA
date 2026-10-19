import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.294', build: 294);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.294', build: 294),
      changes: <String>[
        'Cinco destinos na navegação e Configurações no cabeçalho superior direito.',
        'Lanterna, Resolução e FPS agrupados em janelas; opção experimental de pessoa por ícone.',
        'Estados AO VIVO/pausado e cronômetros, scanner local e salvamento automático de diagnósticos.',
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
