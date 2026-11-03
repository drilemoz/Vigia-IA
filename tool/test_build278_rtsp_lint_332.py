"""Regressão do lint real identificado pelo APK 278 (Flutter analyze)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'lib/sources/rtsp_camera_source.dart'

class Build278RtspLint332(unittest.TestCase):
    def test_reconnect_guard_is_braced(self):
        source = SOURCE.read_text(encoding='utf-8')
        match = re.search(
            r"void _scheduleReconnect\(String reason\)\s*\{.*?"
            r"if \(\s*_disposed \|\| controller == null.*?"
            r"\(_recovery\.exhausted && _recoveryExhaustionLogged\)\)\s*"
            r"\{\s*return;\s*\}",
            source, flags=re.S,
        )
        self.assertIsNotNone(match, 'A guarda RTSP deve ter bloco de retorno entre chaves')

    def test_version_and_news(self):
        self.assertIn('version: 1.0.336+336', (ROOT / 'pubspec.yaml').read_text('utf-8'))
        self.assertTrue((ROOT / 'RELEASE-1.0.336.md').is_file())
        self.assertIn("AppBuildVersion(version: '1.0.336', build: 336)",
                      (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf-8'))

if __name__ == '__main__':
    unittest.main()
