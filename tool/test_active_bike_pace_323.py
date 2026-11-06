from tool.release_version_checks import current_release, version_only, catalog_reference, current_build
"""Regression checks: edit cycling pace without stopping active navigation (323)."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')

class ActiveBikePace323(unittest.TestCase):
    def test_active_navigation_pace_can_be_adjusted(self):
        s=read('lib/screens/map_monitoring_screen.dart')
        method=s.split('Future<void> _editActiveBikePace() async {',1)[1].split('void _dismissRoutePreview()',1)[0]
        for needle in ('_chooseBikeTravelPreferences()', '_sameNavigationTarget(',
                       'setBikeTravelPreferences(selection.preferences)',
                       'setBikeUseHistoricalSpeed(', '_bikeTripPlanner.estimate(',
                       '_refreshBikeTripPlan(route: route, target: target)',
                       '_navigationPanelMinimized = false;'):
            self.assertIn(needle,method)
        self.assertNotIn('_stopNavigation(',method)
    def test_ui_callbacks_and_details(self):
        s=read('lib/screens/map_monitoring_screen.dart')
        self.assertEqual(s.count('onEditBikePace: navigationTarget.travelMode == MapTravelMode.bicycle'),2)
        self.assertIn('final VoidCallback? onEditBikePace;',s)
        self.assertIn("label: const Text('Ajustar ritmo')",s)
        self.assertIn('bikeEstimate!.preferences.ridingHoursPerDay',s)
        self.assertIn('Definir velocidade e horas por dia',s)
        self.assertIn('currentPreferences.averageSpeedKmh != preferences.averageSpeedKmh',s)
        self.assertIn('bikeEstimate!.dayCount',s)
    def test_privacy_and_navigational_events(self):
        s=read('lib/screens/map_monitoring_screen.dart')
        self.assertIn("'editar_ritmo_navegacao_ativa'",s)
        self.assertIn("'ritmo_navegacao_recalculado'",s)
        self.assertNotIn("recordUiAction('mapas', selection.preferences.toString()", s)
    def test_release(self):
        self.assertIn('version: ' + current_release(ROOT), read('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.348.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.348.md').is_file())

if __name__=='__main__': unittest.main()
