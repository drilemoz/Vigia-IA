/// Decisões puras do temporizador do HUD de mapas.
/// O serviço não mantém listeners nem desperta a CPU em segundo plano.
class MapHudRefreshDecision {
  const MapHudRefreshDecision({
    required this.clearStaleProgress,
    required this.rebuildMap,
    required this.refreshDevice,
  });

  final bool clearStaleProgress;
  final bool rebuildMap;
  final bool refreshDevice;
}

class MapHudRefreshPolicy {
  const MapHudRefreshPolicy._();

  static const Duration tickInterval = Duration(seconds: 10);
  static const int deviceRefreshEveryTicks = 3;

  static MapHudRefreshDecision evaluate({
    required int tick,
    required bool gpsFresh,
    required bool navigating,
    required bool recording,
    required bool hasTarget,
    required bool hasNavigationProgress,
  }) {
    final staleProgress = hasTarget && !gpsFresh && hasNavigationProgress;
    final refreshDevice = tick > 0 && tick % deviceRefreshEveryTicks == 0;
    return MapHudRefreshDecision(
      clearStaleProgress: staleProgress,
      rebuildMap: gpsFresh || navigating || recording ||
          staleProgress || refreshDevice,
      refreshDevice: refreshDevice,
    );
  }
}
