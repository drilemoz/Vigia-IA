import '../models/offline_map_package.dart';
import 'offline_map_coverage_policy.dart';

/// Define a origem visual do mapa sem depender da presença de uma chave Google.
/// MBTiles raster não fornece, por si só, recálculo de rotas sem internet.
class OfflineMapRenderPolicy {
  const OfflineMapRenderPolicy._();

  static bool useGoogleRenderer({
    required bool googleSelected,
    required bool sdkConfigured,
    required bool networkOffline,
    required OfflineMapMode mode,
  }) =>
      googleSelected &&
      sdkConfigured &&
      !networkOffline &&
      mode != OfflineMapMode.offline;

  static bool useOnlineRaster({
    required OfflineMapMode mode,
    required bool networkOffline,
  }) =>
      mode != OfflineMapMode.offline && !networkOffline;

  static bool useLocalRaster({
    required OfflineMapMode mode,
    required bool networkOffline,
    required bool packageOpened,
  }) =>
      packageOpened && (mode != OfflineMapMode.online || networkOffline);

  /// Não alarma sobre uma região offline em uso somente como base oculta
  /// atrás de um mapa online. A consulta é por centro da câmera, não GPS.
  static bool warnForCoverage({
    required OfflineMapMode mode,
    required bool networkOffline,
    required OfflineMapCoverageState coverage,
  }) =>
      (mode == OfflineMapMode.offline || networkOffline) &&
      OfflineMapCoveragePolicy.needsWarning(coverage);
}
