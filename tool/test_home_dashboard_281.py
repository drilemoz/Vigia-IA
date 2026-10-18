"""Guarda da Home em três cartões e pop-up de ajustes na versão 281."""
from pathlib import Path
import unittest

R = Path(__file__).resolve().parents[1]

def read(path):
    return (R / path).read_text(encoding='utf-8')

class HomeDashboard281(unittest.TestCase):
    def test_three_independent_compact_cards(self):
        src = read('lib/screens/home_screen_redesign.dart')
        pane = src.split('Widget _buildCompactMonitorCards(', 1)[1].split('Future<void> _openMonitorAdjustments', 1)[0]
        self.assertEqual(3, pane.count('child: _HomeDashboardCard('))
        for label in ("title: 'Uso de dados'", "title: 'Ajuste'", 'title: sourceText'):
            self.assertIn(label, pane)
        self.assertIn('unawaited(_start())', pane)
        self.assertIn('DataUsageService.formatBytes(_dataUsage.snapshot.today.total)', pane)
        self.assertIn('DataUsageScreen()', pane)
        self.assertIn('_openMonitorAdjustments()', pane)
        self.assertNotIn('DataUsageCompactCard(', src)
        self.assertNotIn('_buildMonitorPreparation(', src)

    def test_editor_dialog_keeps_all_existing_settings(self):
        ui = read('lib/screens/home_screen_redesign.dart')
        self.assertIn('showModalBottomSheet<void>(', ui)
        self.assertIn('DraggableScrollableSheet(', ui)
        self.assertIn('ValueListenableBuilder<int>(', ui)
        self.assertIn('children: _monitorConfiguration(activeZones)', ui)
        for name in ('_buildSourcePanel(context)', '_configureObjectFilter',
                     '_configureSmartAlertRules', '_configureSchedule',
                     '_FeatureGrid('):
            self.assertIn(name, ui)
        state = read('lib/screens/home_screen.dart')
        self.assertIn('final ValueNotifier<int> _monitorEditorVersion', state)
        self.assertGreaterEqual(state.count('_monitorEditorVersion.value++'), 2)
        self.assertIn('_updateHomeState(() => _alertLabels', state)
        self.assertIn('_updateHomeState(() => _smartAlertRules', state)
        self.assertIn('_updateHomeState(() => _schedule', state)
        self.assertIn('_monitorEditorVersion.dispose()', state)

    def test_telemetry_is_reachable_without_duplicate_shortcuts(self):
        ui = read('lib/screens/home_screen_redesign.dart')
        self.assertNotIn('Acessos rápidos', ui)
        self.assertNotIn('Widget _buildQuickActions()', ui)
        self.assertIn("'Estado do sistema'", ui)
        self.assertIn("'Telemetria'", ui)
        self.assertIn("onTap: () => _openScreen(const ErrorCenterScreen())", ui)
        self.assertIn('class _HomeDashboardCard extends StatelessWidget', read('lib/screens/home_screen_components.dart'))

    def test_public_version(self):
        self.assertIn('version: 1.0.290+290', read('pubspec.yaml'))
        self.assertIn("version: '1.0.290'", read('lib/screens/app_info_screen_components.dart'))

if __name__ == '__main__':
    unittest.main()
