import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.357', build: 357);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.357', build: 357),
      changes: <String>[
        'Planejamento lista cidades e apoios próximos em ordem de percurso, com quilômetro aproximado e distância da rota.',
        'Rotas novas e salvas identificam locais já armazenados offline, sem precisar ativar GPS ou internet.',
        'Busca manual de apoios percorre mais segmentos de viagens longas, com limites para poupar dados e respeitar o serviço.',
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
