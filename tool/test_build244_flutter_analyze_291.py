"""Regressões dos três diagnósticos reais do flutter analyze no APK 244."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(file):
    return (ROOT / file).read_text(encoding='utf-8')


class Build244FlutterAnalyzeTests(unittest.TestCase):
    def test_app_startup_mount_guard_has_braces(self):
        app = source('lib/app/app.dart')
        self.assertRegex(app, r'addPostFrameCallback\(\(_\) \{\s*if \(!mounted\) \{\s*return;\s*\}')
        self.assertIn('unawaited(_initializeOptionalServices());', app)

    def test_data_usage_pending_write_has_braces(self):
        data = source('lib/services/data_usage_service.dart')
        self.assertRegex(data, r'if \(hadPendingWrite\) \{\s*unawaited\(_persistNow\(\)\);\s*\}')
        self.assertIn('_persistDebounce?.cancel();', data)

    def test_tcp_decoder_matches_uint8list_stream(self):
        scanner = source('lib/services/lan_camera_subnet_scanner.dart')
        self.assertIn('.map((chunk) => latin1.decode(chunk))', scanner)
        self.assertNotIn('.transform(latin1.decoder)', scanner)
        self.assertIn("Socket.connect(host, port, timeout:", scanner)
        self.assertIn("'OPTIONS rtsp://$host:$port/ RTSP/1.0\\r\\n'", scanner)
        self.assertIn('Duration(milliseconds: 500)', scanner)

    def test_version_and_release_synced(self):
        self.assertIn('version: 1.0.300+300', source('pubspec.yaml'))
        self.assertIn("AppBuildVersion(version: '1.0.300', build: 300)", source('lib/services/update_news_catalog.dart'))
        self.assertTrue((ROOT/'RELEASE-1.0.300.md').exists())


if __name__ == '__main__':
    unittest.main()
