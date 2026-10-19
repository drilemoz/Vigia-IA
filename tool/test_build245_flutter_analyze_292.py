"""Regressão para o resultado real do flutter analyze do build 245."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

def source(path):
    return (ROOT/path).read_text(encoding='utf-8')

class Build245FlutterAnalyzeTests(unittest.TestCase):
    def test_transmitter_guard_with_multiline_condition_is_block(self):
        app=source('lib/app/app.dart')
        self.assertRegex(app, r'if \(TransmitterExclusivePolicy\.enabled \|\|\s*_launchMode == AppLaunchMode\.transmission\) \{\s*return;\s*\}')

    def test_data_usage_resumption_guard_with_multiline_condition_is_block(self):
        data=source('lib/services/data_usage_service.dart')
        self.assertRegex(data, r'if \(!_initialized \|\| TransmitterExclusivePolicy\.enabled \|\|\s*_timer\?\.isActive == true\) \{\s*return;\s*\}')
        self.assertIn('Timer.periodic(refreshInterval', data)

    def test_rtsp_byte_type_fix_is_preserved(self):
        scanner=source('lib/services/lan_camera_subnet_scanner.dart')
        self.assertIn('.map((chunk) => latin1.decode(chunk))', scanner)
        self.assertNotIn('.transform(latin1.decoder)', scanner)

    def test_version_and_news_current(self):
        self.assertIn('version: 1.0.294+294', source('pubspec.yaml'))
        self.assertIn("AppBuildVersion(version: '1.0.294', build: 294)", source('lib/services/update_news_catalog.dart'))
        self.assertTrue((ROOT/'RELEASE-1.0.294.md').exists())
