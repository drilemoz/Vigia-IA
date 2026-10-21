"""Protege contra timers pendentes de diagnóstico em testes Flutter de menu."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class Build269NavigationTimers321(unittest.TestCase):
    def test_widget_test_mocks_android_diagnostic_channel_and_cleans_up(self):
        widget = (ROOT / 'test/main_navigation_bar_test.dart').read_text('utf-8')
        self.assertIn("const nativeChannel = MethodChannel('vigiaia/native');", widget)
        self.assertIn('setMockMethodCallHandler(nativeChannel, (call) async', widget)
        self.assertIn('addTearDown(() => messenger.setMockMethodCallHandler(nativeChannel, null))', widget)
        self.assertIn('await tester.pumpAndSettle()', widget)

    def test_widget_test_verifies_actual_navigation_events(self):
        widget = (ROOT / 'test/main_navigation_bar_test.dart').read_text('utf-8')
        for label in ('Câmeras', 'Galeria', 'Mapas'):
            self.assertIn(f'acao=aba_{label}', widget)
        self.assertIn('area=navegacao', widget)
        self.assertRegex(widget, r'expect\(nativeEvents|final details = nativeEvents')

    def test_production_logging_remains_enabled(self):
        service = (ROOT / 'lib/services/automatic_diagnostics_service.dart').read_text('utf-8')
        nav = (ROOT / 'lib/widgets/main_navigation_bar.dart').read_text('utf-8')
        self.assertIn("_send('diagnosticEvent'", service)
        self.assertIn('setUiSection(_mainDestinations[index].label)', nav)

    def test_current_version_synced(self):
        self.assertIn('version: 1.0.321+321', (ROOT / 'pubspec.yaml').read_text('utf-8'))
        self.assertTrue((ROOT / 'RELEASE-1.0.321.md').is_file())
        self.assertTrue((ROOT / 'VALIDATION-1.0.321.md').is_file())

if __name__ == '__main__':
    unittest.main()
