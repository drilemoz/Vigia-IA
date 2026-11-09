"""Contratos da nova interface 370. Estruturais, sem substituir flutter test."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCREEN = (ROOT / 'lib/screens/trip_planning_screen.dart').read_text('utf8')


class CompactPlanning370(unittest.TestCase):
    def test_only_one_stage_is_instantiated_not_a_long_list(self):
        stage = SCREEN.split('  Widget _stageSlides(', 1)[1].split('  Widget _planningTools(', 1)[0]
        self.assertIn('days[selected]', stage)
        self.assertIn('_dayCard(days[selected], trip, terrain[selected])', stage)
        self.assertNotIn('_dayCard(simulatedDays[i]', SCREEN)
        self.assertIn('if (days.length <= 14)', stage)
        self.assertIn('Mostrar dia ${i + 1}', stage)

    def test_navigation_has_bounds_swipe_arrows_and_animation(self):
        self.assertIn('if (next < 0 || next >= count || next == _selectedDayIndex) return;', SCREEN)
        for fragment in ('onHorizontalDragEnd:', 'AnimatedSwitcher(',
                         "const Text('Anterior')", "Text('Próximo dia'",
                         '_switchStage(selected - 1, days.length)',
                         '_switchStage(selected + 1, days.length)'):
            self.assertIn(fragment, SCREEN)

    def test_route_changes_reset_selection_but_do_not_change_saved_trip(self):
        self.assertGreaterEqual(SCREEN.count('_selectedDayIndex = 0;'), 4)
        switch = SCREEN.split('void _switchStage(', 1)[1].split('Widget _stageSlides(', 1)[0]
        self.assertNotIn('_draft =', switch)
        self.assertNotIn('_library.', switch)
        self.assertNotIn('fetchAlternatives(', switch)

    def test_map_and_tools_are_lazy_and_offline_audit_remains_manual(self):
        self.assertIn('if (_showRouteMap) _routeMap(trip)', SCREEN)
        self.assertIn('if (_showTripTools) _planningTools(trip, plan)', SCREEN)
        for fragment in ('_offlineReadinessCard(trip, plan)',
                         "const Text('Clima por etapa')",
                         "const Text('Preparação offline')",
                         "const Text('Localidades e pontos de apoio')",
                         'TripDayReadinessService.notices(',
                         '_weatherDayLine(day.day, trip)',
                         '_editStopCheck(day, trip)'):
            self.assertIn(fragment, SCREEN)

    def test_primary_action_and_export_still_use_original_methods(self):
        for fragment in ("const Text('Salvar viagem')", "value: 'gpx'",
                         "value: 'json'", "value: 'delete'", '_save()',
                         '_exportTrip(trip, value)', '_discardOrDeleteCurrent(trip)'):
            self.assertIn(fragment, SCREEN)


if __name__ == '__main__':
    unittest.main()
