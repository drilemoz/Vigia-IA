from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class Diagnostics314Tests(unittest.TestCase):
    def test_production_rules(self):
        compiler = shutil.which('kotlinc')
        if not compiler: self.skipTest('kotlinc not installed')
        with tempfile.TemporaryDirectory() as temp:
            jar = Path(temp) / 'test.jar'
            subprocess.run([compiler, str(ROOT/'tool/android/DiagnosticPolicy.kt'),
                            str(ROOT/'tool/kotlin/Diagnostics314Test.kt'), '-include-runtime', '-d', str(jar)], check=True, timeout=90)
            subprocess.run(['java', '-jar', str(jar)], check=True, timeout=20)

    def test_dart_redaction(self):
        dart = shutil.which('dart')
        if not dart: self.skipTest('Dart SDK not installed')
        subprocess.run([dart, str(ROOT/'tool/dart/diagnostic_redactor_test.dart')], check=True, timeout=30)

    def test_native_survives_bootstrap(self):
        for name in ['AppDiagnostics', 'VigiaApplication', 'DiagnosticPolicy']:
            self.assertEqual((ROOT/f'tool/android/{name}.kt').read_bytes(),
                             (ROOT/f'android/app/src/main/kotlin/com/vigiaia/app/{name}.kt').read_bytes())
            self.assertIn(name, (ROOT/'tool/bootstrap_android.sh').read_text())
        self.assertIn('com.vigiaia.app.VigiaApplication', (ROOT/'tool/AndroidManifest.xml').read_text())

    def test_hooks_and_recovery_order(self):
        main = (ROOT/'lib/main.dart').read_text()
        self.assertLess(main.index('FlutterError.onError'), main.index('await SystemUiService'))
        self.assertLess(main.index('PlatformDispatcher.instance.onError'), main.index('await SystemUiService'))
        app = (ROOT/'lib/app/app.dart').read_text()
        self.assertIn('DiagnosticRecoveryHost(child: _StartupGate())', app)
        native = (ROOT/'tool/android/AppDiagnostics.kt').read_text()
        self.assertLess(native.index('putString("incidents", incidents.toString())'), native.index('startedAt = System.currentTimeMillis()'))
        self.assertIn('finally {', native)
        self.assertIn('delegate.uncaughtException(thread, error)', native)
        self.assertIn('while (samples.size > 30)', native)
        self.assertIn('while (events.size > 120)', native)

if __name__ == '__main__': unittest.main()
