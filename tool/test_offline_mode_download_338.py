"""Contratos da seleção de mapas MBTiles e downloads seguros na 1.0.343.

Estes testes estáticos complementam, mas não substituem flutter analyze/test.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text('utf-8')

class OfflineMap338(unittest.TestCase):
    def test_google_renderer_respects_offline_selection(self):
        policy = read('lib/services/offline_map_render_policy.dart')
        screen = read('lib/screens/map_monitoring_screen.dart')
        self.assertIn('mode != OfflineMapMode.offline', policy)
        self.assertIn('OfflineMapRenderPolicy.useGoogleRenderer(', screen)
        self.assertIn('mode: _offlineMaps.mode,', screen)
        self.assertTrue((ROOT / 'test/offline_map_render_policy_test.dart').exists())

    def test_online_tiles_are_not_fetched_in_offline_mode(self):
        policy = read('lib/services/offline_map_render_policy.dart')
        screen = read('lib/screens/map_monitoring_screen.dart')
        self.assertIn('mode != OfflineMapMode.offline && !networkOffline', policy)
        self.assertIn('OfflineMapRenderPolicy.useOnlineRaster(', screen)
        self.assertIn('if (useOnline)', screen)
        self.assertIn('if (useOfflineLayer)', screen)

    def test_warns_when_mbtile_missing_or_outside_visible_area(self):
        screen = read('lib/screens/map_monitoring_screen.dart')
        coverage = read('lib/services/offline_map_coverage_policy.dart')
        self.assertIn('_mapViewportCenter', screen)
        self.assertIn('latitude: displayedCenter.latitude', screen)
        self.assertIn('OfflineMapRenderPolicy.warnForCoverage(', screen)
        self.assertIn('OfflineMapCoverageState.noPackage', coverage)
        self.assertIn('OfflineMapCoverageState.corridorUnverified', coverage)

    def test_downloads_preserve_requested_mode(self):
        service = read('lib/services/offline_map_service.dart')
        for method_name, end_name in [
            ('_downloadStadiaTiles(', '_fetchStadiaTileWithRetry('),
            ('downloadPackage(', 'importPackage('),
            ('importPackage(', 'updateStadiaPackage('),
        ]:
            segment = service.split('Future<OfflineMapPackage> ' + method_name, 1)[1].split('Future<',1)[0]
            self.assertNotIn('_mode = OfflineMapMode.automatic;', segment)

    def test_safe_update_never_deletes_original_before_success(self):
        service = read('lib/services/offline_map_service.dart')
        update = service.split('Future<OfflineMapPackage> updateStadiaPackage(', 1)[1].split('Future<void> setActive(', 1)[0]
        self.assertIn('stadiaSafeAvailableCacheBytes', update)
        self.assertIn('final replacement = await downloadStadiaRegion(', update)
        self.assertLess(update.index('final replacement = await downloadStadiaRegion('), update.index('await deletePackage(item.id);'))

    def test_network_pause_cancel_and_retry(self):
        service = read('lib/services/offline_map_service.dart')
        self.assertIn('void cancelDownload()', service)
        self.assertIn('_activeDownloadClient?.close(force: true)', service)
        self.assertIn('Future<_DownloadedTile> _fetchStadiaTileWithRetry(', service)
        self.assertIn('attempt < 3', service)
        self.assertIn('response.timeout(const Duration(seconds: 30))', service)
        self.assertIn('request.followRedirects = false', service)
        ui = read('lib/widgets/offline_map_manager_sheet.dart')
        self.assertIn('if (_service.canCancelDownload)', ui)

    def test_deleted_last_package_does_not_activate_google_implicitly(self):
        service = read('lib/services/offline_map_service.dart')
        self.assertNotIn('if (_mode == OfflineMapMode.offline && activePackage == null)', service)
        self.assertIn('O modo Offline permanece escolhido', service)
        sheet = read('lib/widgets/offline_map_manager_sheet.dart')
        self.assertIn('_service.mode == OfflineMapMode.offline,', sheet)

    def test_imported_maps_require_a_real_tile(self):
        service = read('lib/services/offline_map_service.dart')
        self.assertIn("check.select('SELECT tile_data FROM tiles LIMIT 1')", service)
        self.assertIn('_isRasterBytes(rows.first', service)
        self.assertIn('Baixe ou selecione um pacote MBTiles válido', service)

    def test_document_and_version(self):
        self.assertIn('version: 1.0.350+350', read('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.348.md').exists())
        self.assertTrue((ROOT / 'VALIDATION-1.0.348.md').exists())

if __name__ == '__main__':
    unittest.main()
