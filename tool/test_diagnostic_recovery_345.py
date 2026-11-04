"""Contracts for Android exit-recovery changes (Flutter tests run in CI)."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class Recovery345Tests(unittest.TestCase):
    def test_native_exit_matched_to_previous_process(self):
        src = (ROOT/'tool/android/AppDiagnostics.kt').read_text()
        self.assertIn('DiagnosticPolicy.belongsToSession(', src)
        self.assertIn('it.pid, now', src)
        self.assertIn('.put("pid", android.os.Process.myPid())', src)
        self.assertIn('.put("sourceVersion", previous.optString("version"', src)
        self.assertIn('.put("severity", severity)', src)
        self.assertIn('.put("recoveryReady", recoveryReady)', src)

    def test_recovery_resilient_and_not_mislabelled(self):
        service = (ROOT/'lib/services/automatic_diagnostics_service.dart').read_text()
        widget = (ROOT/'lib/widgets/diagnostic_recovery_host.dart').read_text()
        self.assertIn('attempt < 3', service)
        self.assertIn("'available': false", service)
        self.assertIn('with WidgetsBindingObserver', widget)
        self.assertIn('didChangeAppLifecycleState', widget)
        self.assertIn("'Encerramento anterior do Android'", widget)
        self.assertIn("'Falha recuperada de versão anterior'", widget)
        self.assertIn('_shownIncidentIds', widget)
        self.assertIn('cachedMemoryExit', widget)
        self.assertTrue((ROOT/'test/diagnostic_recovery_v345_test.dart').is_file())

    def test_policy_keeps_user_stop_nonfatal(self):
        policy = (ROOT/'tool/android/DiagnosticPolicy.kt').read_text()
        self.assertIn('importance >= 400', policy)
        self.assertIn('if (status == 9)', policy)
        self.assertIn('else -> null', policy)

    def test_version(self):
        self.assertIn('version: 1.0.347+347', (ROOT/'pubspec.yaml').read_text())
        self.assertTrue((ROOT/'RELEASE-1.0.347.md').exists())

if __name__ == '__main__': unittest.main()
