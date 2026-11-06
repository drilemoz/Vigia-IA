from tool.release_version_checks import current_release, version_only, catalog_reference, current_build
"""Regressão estrutural do erro de timeout em testes Flutter do build 264.

Não substitui flutter test no CI.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / 'test/diagnostic_recovery_host_test.dart'


class Build264RecoveryRegression(unittest.TestCase):
    def test_dialog_wait_is_bounded_and_three_cases_use_it(self):
        source = TEST.read_text('utf8')
        self.assertIn('Future<void> waitForRecoveryDialog(WidgetTester tester, {', source)
        self.assertIn('frame < 20', source)
        self.assertEqual(source.count('await waitForRecoveryDialog(tester);'), 3)
        self.assertIn("fail('O aviso de recuperação não apareceu", source)

    def test_no_settle_until_modal_closes(self):
        source = TEST.read_text('utf8')
        scenarios = source.split('  testWidgets(')
        self.assertEqual(len(scenarios), 6)
        for scenario in scenarios[2:]:
            self.assertIn('await waitForRecoveryDialog(tester', scenario)
            before_dialog = scenario.split('await waitForRecoveryDialog(tester', 1)[0]
            self.assertNotIn('await tester.pumpAndSettle();', before_dialog)
        failure_case = next(s for s in scenarios if s.startswith("'falha ao salvar"))
        self.assertNotIn('await tester.pumpAndSettle();', failure_case)
        self.assertIn("expect(find.textContaining('Não foi possível exportar')", failure_case)
        self.assertIn('expect(acknowledgements, 0)', failure_case)
        success_case = next(s for s in scenarios if s.startswith("'exporta os dados"))
        self.assertIn("expect(operations, ['saved', 'acknowledged'])", success_case)

    def test_application_behavior_unchanged(self):
        source = (ROOT / 'lib/widgets/diagnostic_recovery_host.dart').read_text('utf8')
        self.assertIn('CircularProgressIndicator()', source)
        self.assertIn('await showDialog<void>(', source)
        self.assertIn('acknowledge', source)
        self.assertIn('exportIncident', source)

    def test_version(self):
        self.assertIn('version: ' + current_release(ROOT), (ROOT / 'pubspec.yaml').read_text('utf8'))
        self.assertTrue((ROOT / 'RELEASE-1.0.348.md').is_file())


if __name__ == '__main__':
    unittest.main()
