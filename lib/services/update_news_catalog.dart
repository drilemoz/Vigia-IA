import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// Apenas a versão instalada aparece no pop-up Novidades.
  static const currentVersion =
      AppBuildVersion(version: '1.0.360', build: 360);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.360', build: 360),
      changes: <String>[
        'Reserva opcional de tempo por 100 m de subida com dados altimétricos disponíveis, sem extrapolar lacunas.',
        'Avisos por dia de pedal acima do limite, chegada tardia e parada sem confirmação.',
        'Preferências salvas com a viagem e horário da consulta manual de clima ajustado à simulação.',
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
