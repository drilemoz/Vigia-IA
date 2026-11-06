"""Contratos de regressão de fonte para a primeira etapa offline da 1.0.354.

Não substituem flutter analyze/test ou testes no aparelho.
"""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def source(path):
    return (ROOT/path).read_text(encoding='utf-8')

class OfflinePlanning354Tests(unittest.TestCase):
    def test_saved_poi_activation_does_not_require_gps(self):
        text = source('lib/services/route_explorer_service.dart')
        block = text.split('Future<void> activateOfflinePackage', 1)[1].split('Future<void> removeOfflinePackage', 1)[0]
        self.assertIn('if (current != null)', block)
        self.assertIn('else {', block)
        self.assertIn("_results = selected.items", block)
        self.assertIn("_lastSource = 'offline';", block)
        self.assertIn('Distâncias indisponíveis', block)

    def test_search_without_gps_can_recover_saved_package(self):
        text = source('lib/services/route_explorer_service.dart')
        self.assertIn('final offline = _activateSelectedOfflineWithoutGps();', text)
        self.assertIn("'Exibindo “${selected.name}” sem GPS; distâncias indisponíveis.'", text)
        self.assertIn("_results = _offlineResults", text)

    def test_manual_area_falls_back_to_deduplicated_local_pois(self):
        text = source('lib/services/route_explorer_service.dart')
        area = text.split('Future<void> searchAround', 1)[1].split('void _markResultsAsCache', 1)[0]
        self.assertIn('if (_connectivity.isOffline)', area)
        self.assertIn('_offlineItemsAround(center)', area)
        self.assertIn('} catch (_) {', area)
        self.assertIn("_areaResults = _offlineItemsAround(center)", area)
        self.assertIn('unique.putIfAbsent(key', text)
        self.assertIn('if (best == null) {', text)
        self.assertIn('_offlineResults = const <RouteExplorerResult>[];', text)

    def test_planning_has_retained_mbtiles_provider_and_coverage_warning(self):
        text = source('lib/screens/trip_planning_screen.dart')
        for fragment in ('RetainedMbTilesTileProvider.fromPath',
                         '_previewOfflineTileProvider?.release();',
                         'tileProvider: provider',
                         'DropdownButtonFormField<String>',
                         'Atenção: $matches de $count amostras',
                         '_offlinePoisOnRoute(route)',
                         'trip.places.isNotEmpty'):
            self.assertIn(fragment, text)

    def test_nearby_dialog_exposes_saved_packages_and_gps_limitation(self):
        text = source('lib/screens/map_monitoring_screen.dart')
        self.assertIn("Abrir pacotes salvos (${service.offlinePackages.length}) · sem GPS", text)
        self.assertIn('Sem GPS\\ndistância indisponível', text)

if __name__ == '__main__':
    unittest.main()
