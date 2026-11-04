import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/offline_map_package.dart';
import 'package:vigiaia/services/offline_map_coverage_policy.dart';
import 'package:vigiaia/services/offline_map_render_policy.dart';

void main() {
  group('Modo Offline prevalece sobre Google Maps', () {
    test('Google Maps não abre no modo Offline mesmo com internet e chave', () {
      expect(
        OfflineMapRenderPolicy.useGoogleRenderer(
          googleSelected: true, sdkConfigured: true,
          networkOffline: false, mode: OfflineMapMode.offline,
        ),
        isFalse,
      );
    });
    test('Google Maps abre no modo Automático se houver internet e chave', () {
      expect(
        OfflineMapRenderPolicy.useGoogleRenderer(
          googleSelected: true, sdkConfigured: true,
          networkOffline: false, mode: OfflineMapMode.automatic,
        ),
        isTrue,
      );
    });
    test('sem internet, Google desligado, MBTiles ligado', () {
      expect(
        OfflineMapRenderPolicy.useGoogleRenderer(
          googleSelected: true, sdkConfigured: true,
          networkOffline: true, mode: OfflineMapMode.automatic,
        ),
        isFalse,
      );
      expect(
        OfflineMapRenderPolicy.useLocalRaster(
          mode: OfflineMapMode.automatic, networkOffline: true,
          packageOpened: true,
        ),
        isTrue,
      );
    });
    test('o modo Offline não cria camadas online', () {
      expect(OfflineMapRenderPolicy.useOnlineRaster(
        mode: OfflineMapMode.offline, networkOffline: false,
      ), isFalse);
      expect(OfflineMapRenderPolicy.useLocalRaster(
        mode: OfflineMapMode.offline, networkOffline: false,
        packageOpened: true,
      ), isTrue);
    });
    test('indica falta de pacote apenas quando a imagem local é necessária', () {
      expect(OfflineMapRenderPolicy.warnForCoverage(
        mode: OfflineMapMode.automatic, networkOffline: false,
        coverage: OfflineMapCoverageState.noPackage,
      ), isFalse);
      expect(OfflineMapRenderPolicy.warnForCoverage(
        mode: OfflineMapMode.offline, networkOffline: false,
        coverage: OfflineMapCoverageState.noPackage,
      ), isTrue);
      expect(OfflineMapCoveragePolicy.warningLabel(
        OfflineMapCoverageState.noPackage,
      ), contains('Sem mapa'));
    });
    test('alerta quando o usuário navega fora da área ou do zoom', () {
      for (final status in [
        OfflineMapCoverageState.outsideBounds,
        OfflineMapCoverageState.outsideZoom,
        OfflineMapCoverageState.corridorUnverified,
      ]) {
        expect(OfflineMapRenderPolicy.warnForCoverage(
          mode: OfflineMapMode.offline, networkOffline: false,
          coverage: status,
        ), isTrue);
      }
    });
  });
}
