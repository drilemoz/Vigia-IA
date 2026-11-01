import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.327', build: 327);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.327', build: 327),
      changes: <String>[
        'Central de Serviços e APIs ampliada para seis provedores opcionais, incluindo Geoapify, OpenRouteService e Open-Meteo.',
        'Ajuda individual e guia geral explicam como conseguir as chaves, limites e alternativas gratuitas.',
        'Geoapify e OpenRouteService: salvar, colar, revelar, copiar, remover e testar conexões com chaves protegidas.',
        'Google Maps ganhou controles de colar, copiar e verificar configuração, distinguindo o teste real pelo SDK.',
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
