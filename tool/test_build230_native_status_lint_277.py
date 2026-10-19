"""Guarda do aviso fatal invalid_null_aware_operator no APK 230."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Build230NativeStatusLint(unittest.TestCase):
    def test_native_status_has_nonnull_promotion_before_ready(self):
        src = (ROOT / 'lib/screens/native_transmitter_screen.dart').read_text(encoding='utf-8')
        self.assertIn('_elapsed(s!.seconds)', src)
        self.assertIn('if (s != null && !s.ready)', src)
        running_section = src.split('if (running) ...[', 1)[1].split('const SizedBox(height: 12)', 1)[0]
        self.assertNotIn('s?.ready != true', running_section)
        self.assertNotIn('s?.ready == false', running_section)
        self.assertIn('final ready = s?.ready == true;', src)
        self.assertIn('disabled: busy || !ready', src)
        self.assertNotIn('disabled: busy || s?.ready', src)

    def test_current_version_matches_news_without_stale_build(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        match = re.search(r'(?m)^version: (\d+\.\d+\.\d+)\+(\d+)$', pubspec)
        self.assertIsNotNone(match, 'pubspec.yaml must declare a version and build')
        version, build = match.groups()
        self.assertEqual(int(version.split('.')[-1]), int(build))
        news = (ROOT / 'lib/services/update_news_catalog.dart').read_text(encoding='utf-8')
        expected = f"AppBuildVersion(version: '{version}', build: {build})"
        self.assertEqual(news.count(expected), 2)

if __name__ == '__main__':
    unittest.main()
