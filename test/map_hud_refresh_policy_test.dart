import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_hud_refresh_policy.dart';

void main() {
  test('HUD em repouso atualiza o mapa em cadência reduzida', () {
    for (var tick = 1; tick <= 6; tick++) {
      final result = MapHudRefreshPolicy.evaluate(
        tick: tick,
        gpsFresh: false,
        navigating: false,
        recording: false,
        hasTarget: false,
        hasNavigationProgress: false,
      );
      expect(result.rebuildMap, tick % 3 == 0);
      expect(result.refreshDevice, tick % 3 == 0);
      expect(result.clearStaleProgress, isFalse);
    }
  });

  test('GPS fresco e navegação ou gravação atualizam sem atraso', () {
    for (final input in <(bool, bool, bool)>[
      (true, false, false),
      (false, true, false),
      (false, false, true),
    ]) {
      final result = MapHudRefreshPolicy.evaluate(
        tick: 1,
        gpsFresh: input.$1,
        navigating: input.$2,
        recording: input.$3,
        hasTarget: false,
        hasNavigationProgress: false,
      );
      expect(result.rebuildMap, isTrue);
      expect(result.refreshDevice, isFalse);
    }
  });

  test('GPS antigo com destino limpa manobra obsoleta imediatamente', () {
    final result = MapHudRefreshPolicy.evaluate(
      tick: 1,
      gpsFresh: false,
      navigating: false,
      recording: false,
      hasTarget: true,
      hasNavigationProgress: true,
    );
    expect(result.clearStaleProgress, isTrue);
    expect(result.rebuildMap, isTrue);
  });

  test('Progresso sem destino e ciclo zero não forçam limpeza', () {
    final result = MapHudRefreshPolicy.evaluate(
      tick: 0,
      gpsFresh: false,
      navigating: false,
      recording: false,
      hasTarget: false,
      hasNavigationProgress: true,
    );
    expect(result.clearStaleProgress, isFalse);
    expect(result.rebuildMap, isFalse);
    expect(result.refreshDevice, isFalse);
  });
}
