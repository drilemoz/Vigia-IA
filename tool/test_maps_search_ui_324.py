"""Regressões de busca de localidades e layout do mapa/planejamento (324)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text('utf-8')

class MapSearchUi324(unittest.TestCase):
    def test_city_boundaries_are_valid_without_accepting_unrelated_pois(self):
        m = read('lib/models/map_destination_search.dart')
        self.assertIn("category == 'boundary' && type == 'administrative'", m)
        self.assertIn('MapDestinationKind.pointOfInterest', m)
        s = read('lib/services/map_destination_search_service.dart')
        self.assertIn('MapDestinationKindX.fromNominatim(', s)
        self.assertIn('nominatim.openstreetmap.org', s)

    def test_search_is_explicit_results_are_selectable(self):
        s=read('lib/screens/trip_planning_screen.dart')
        block=s.split('void _typing(',1)[1].split('Future<void> _searchCity(',1)[0]
        self.assertIn('_citySearch.updateLocalQuery(',block)
        self.assertNotIn('searchSubmitted(',block) # política pública Nominatim: sem autocomplete
        for expected in ('_citySearch.searchSubmitted(', 'onSubmitted: (_) => unawaited(_searchCity(origin: origin))',
                         'Buscar "$activeText" online', 'Selecione um resultado para habilitar Avançar',
                         'onTap: () => _selectCity(place)'):
            self.assertIn(expected,s)

    def test_wizard_is_responsive_and_settings_are_2x2(self):
        s=read('lib/screens/trip_planning_screen.dart')
        wizard=s.split('Future<void> _newRouteWizard()',1)[1].split('Future<void> _exportTrip(',1)[0]
        self.assertIn('return Dialog(',wizard)
        self.assertIn('Flexible(child: SingleChildScrollView(',wizard)
        self.assertIn('OverflowBar(',wizard)
        settings=s.split('Widget _settings()',1)[1].split('List<MapDestinationSearchResult> _nearbyRoutePlaces',1)[0]
        self.assertEqual(settings.count('Row(children:'),3) # 2 filas de controle, 1 do popup
        self.assertIn("_choice('Almoço'",settings)
        self.assertIn("_choice('Pausa'",settings)
        self.assertIn("_choice('A cada'",settings)
        self.assertIn('Saída ${_departure.format(context)}',settings)

    def test_map_header_has_no_white_appbar_and_hud_has_reserved_space(self):
        shell=read('lib/screens/map_workspace_shell.dart')
        self.assertNotIn('appBar: AppBar(',shell)
        self.assertIn('body: Stack(children:',shell)
        self.assertIn('workspaceHeaderHeight: 0',shell)
        map_screen=read('lib/screens/map_monitoring_screen.dart')
        self.assertIn('widget.workspaceHeaderHeight +',map_screen)
        self.assertIn('constraints.maxHeight * 0.47',map_screen)
        self.assertIn('speedSource: liveGps == null',map_screen)

    def test_direction_and_duration_are_not_unlabeled_or_truncated(self):
        hud=read('lib/widgets/map_status_indicators.dart')
        self.assertIn('headingSourceLabel',hud)
        self.assertIn('Sem velocidade',hud)
        preview=read('lib/services/map_route_preview_metrics.dart')
        self.assertIn('.round() + 59) ~/ 60',preview)
        screen=read('lib/screens/map_monitoring_screen.dart')
        self.assertIn('(duration.inSeconds + 59) ~/ 60',screen)
        self.assertIn('Comparação limitada a distância e tempo',read('lib/widgets/map_route_preview_card.dart'))

if __name__ == '__main__': unittest.main()
