"""Regressão da Home 282: operações compactas e Telemetria sem atalhos redundantes."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def read(name): return (ROOT / name).read_text(encoding='utf-8')

class HomeOrganization282(unittest.TestCase):
    def test_dashboard_has_no_repeated_navigation(self):
        ui = read('lib/screens/home_screen_redesign.dart')
        self.assertNotIn('Acessos rápidos', ui)
        self.assertNotIn('_buildQuickActions', ui)
        self.assertIn('SliverFillRemaining(', ui)
        self.assertIn('_buildSystemStatusStrip(sourceText, activeZones)', ui)
        self.assertIn('hasScrollBody: false', ui)

    def test_modes_are_actions_and_existing_services_are_reused(self):
        ui = read('lib/screens/home_screen_redesign.dart')
        self.assertEqual(ui.count('VigiaModeCard('), 4)
        for name in ('Monitorar', 'Transmitir', 'Receber', 'ESP32'):
            self.assertIn("title: '%s'" % name, ui)
        for action in ('_startRememberedCamera()', 'NativeTransmitterScreen()',
                       'MonitorConnectScreen()', 'Esp32SettingsScreen()'):
            self.assertIn(action, ui)
        self.assertIn('navigateToMainDestination(context, index, currentIndex: 0)', ui)

    def test_data_and_adjustment_actions_preserved(self):
        ui = read('lib/screens/home_screen_redesign.dart')
        self.assertEqual(ui.count('child: _HomeDashboardCard('), 3)
        self.assertIn('DataUsageScreen()', ui)
        self.assertIn('unawaited(_start())', ui)
        self.assertIn('_openMonitorAdjustments()', ui)
        self.assertIn('children: _monitorConfiguration(activeZones)', ui)

    def test_status_is_configuration_not_invented_live_metrics(self):
        ui = read('lib/screens/home_screen_redesign.dart')
        self.assertIn('_loadedSettings.aiEnabled', ui)
        self.assertIn('_schedule.enabled', ui)
        self.assertIn('onTap: () => _openScreen(const ErrorCenterScreen())', ui)
        self.assertNotIn('Câmera parada · IA pronta · Sem gravação', ui)
        self.assertIn('constraints.maxHeight < 570', ui)

    def test_version(self):
        self.assertIn('version: 1.0.293+293', read('pubspec.yaml'))

if __name__ == '__main__':
    unittest.main()
