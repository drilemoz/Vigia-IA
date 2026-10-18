"""Regressões fatais verificadas nos logs do workflow APK 227."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parent.parent


class Build227LintContract(unittest.TestCase):
    def test_recording_uses_null_safe_access_in_native_ui(self):
        source = (ROOT / 'lib/screens/native_transmitter_screen.dart').read_text()
        self.assertNotIn('icon: Icon(s.recording ?', source)
        self.assertNotIn('label: Text(s.recording ?', source)
        self.assertIn('icon: Icon(s?.recording == true ?', source)
        self.assertIn('label: Text(s?.recording == true ?', source)

    def test_mounted_snackbar_condition_is_braced(self):
        source = (ROOT / 'lib/screens/camera_mode_screen.dart').read_text()
        self.assertRegex(source,
            re.compile(r'if \(mounted\) \{\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(const SnackBar\(', re.M))
        self.assertIn('Desligue o transmissor nativo antes de iniciar o antigo.', source)

    def test_current_version_is_updated(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text()
        match = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$', pubspec, re.M)
        self.assertIsNotNone(match)
        version, build = match.groups()
        self.assertIn(f"AppBuildVersion(version: '{version}', build: {build})",
                      (ROOT / 'lib/services/update_news_catalog.dart').read_text())

if __name__ == '__main__':
    unittest.main()
