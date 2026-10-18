"""Guarda do aviso fatal invalid_null_aware_operator no APK 230."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Build230NativeStatusLint(unittest.TestCase):
    def test_native_status_has_nonnull_promotion_before_ready(self):
        src = (ROOT / 'lib/screens/native_transmitter_screen.dart').read_text(encoding='utf-8')
        self.assertIn('_elapsed(s!.seconds)', src)
        self.assertIn('if (!s.ready)', src)
        running_section = src.split('if (running) ...[', 1)[1].split('const SizedBox(height: 12)', 1)[0]
        self.assertNotIn('s?.ready != true', running_section)
        self.assertNotIn('s?.ready == false', running_section)

    def test_current_version_is_287(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        self.assertRegex(pubspec, r'(?m)^version: 1\.0\.289\+289$')
        news = (ROOT / 'lib/services/update_news_catalog.dart').read_text(encoding='utf-8')
        self.assertIn("AppBuildVersion(version: '1.0.289', build: 289)", news)

if __name__ == '__main__':
    unittest.main()
