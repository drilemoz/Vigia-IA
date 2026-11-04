"""APK 291: recovery modal must distinguish historic incidents from current ones."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RecoveryDialog346ContractTests(unittest.TestCase):
    def test_old_version_uses_historic_title_in_widget_and_test(self):
        widget = (ROOT / 'lib/widgets/diagnostic_recovery_host.dart').read_text('utf-8')
        tests = (ROOT / 'test/diagnostic_recovery_host_test.dart').read_text('utf-8')
        self.assertIn("? 'Falha recuperada de versão anterior'", widget)
        self.assertIn("String title = 'Falha recuperada de versão anterior'", tests)
        self.assertIn("'session': <String, Object?>{'version': '1.0.314'", tests)
        self.assertIn("expect(find.text('Falha recuperada de versão anterior'), findsOneWidget)", tests)
        self.assertIn("Registro da versão 1.0.314", tests)

    def test_current_incident_retains_previous_title_and_actions(self):
        tests = (ROOT / 'test/diagnostic_recovery_host_test.dart').read_text('utf-8')
        self.assertIn("{'version': AppMetadata.version}", tests)
        self.assertIn("title: 'Erro detectado no último uso'", tests)
        self.assertIn("testWidgets('falha ao salvar conserva incidente", tests)
        self.assertIn("testWidgets('exporta os dados anteriores antes", tests)
        self.assertIn('await tester.tap(find.text(\'Agora não\'))', tests)

    def test_build_version_consistent(self):
        meta = (ROOT / 'pubspec.yaml').read_text('utf-8')
        self.assertIn('version: 1.0.350+350', meta)
        self.assertTrue((ROOT / 'RELEASE-1.0.348.md').is_file())


if __name__ == '__main__':
    unittest.main()
