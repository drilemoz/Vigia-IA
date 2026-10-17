import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.269', build: 269);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.269', build: 269),
      changes: <String>[
        'Botão Mapa do Ao vivo agora alterna para o mapa compacto da sessão.',
        'Botão Áudio abre um popup/modal com acesso direto aos controles de voz e sons.',
        'Painel Status da sessão ficou mais claro e organizado; fotos de Eventos abrem com fallback mais seguro.'
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
