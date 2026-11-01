import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.325', build: 325);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.325', build: 325),
      changes: <String>[
        'Gemini opcional no Vigia Maps: campo de chave, salvar, colar, copiar, mostrar, remover e testar API com modelo selecionável.',
        'Busca assistida traduz perguntas em consultas cartográficas; resultados navegáveis vêm do OpenStreetMap ou índice local.',
        'Credencial Gemini criptografada no Android Keystore, separada do Google Maps e excluída dos backups.',
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
