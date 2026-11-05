"""APK 294: enforce explicit braces around the battery telemetry guard.

These focused structural tests do not replace `flutter analyze` in CI.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class Build294FlutterAnalyze350Tests(unittest.TestCase):
    def test_battery_guard_is_explicit_block_without_changing_set_state(self):
        source = (ROOT / 'lib/screens/map_monitoring_screen.dart').read_text('utf-8')
        match = re.search(r'Future<void> _refreshBattery\(\) async \{(?P<body>.*?)\n  \}', source, re.S)
        self.assertIsNotNone(match, 'Battery method missing')
        body = match.group('body')
        self.assertRegex(body,
            r'if \(\s*!mounted \|\|\s*!_appActive \|\|\s*'
            r'telemetry\.batteryPercent == _phoneBattery\) \{\s*return;\s*\}')
        self.assertNotRegex(body, r'== _phoneBattery\)\s*return;')
        self.assertIn('setState(() => _phoneBattery = telemetry.batteryPercent);', body)
        self.assertIn('} catch (_) {', source)

    def test_version_current_and_regression_registered(self):
        source = (ROOT / 'pubspec.yaml').read_text('utf-8')
        self.assertIn('version: 1.0.353+353', source)
        self.assertIn('tool/test_build294_flutter_analyze_350.py',
            (ROOT / 'tool/verify_project.sh').read_text('utf-8'))
        self.assertTrue((ROOT / 'RELEASE-1.0.351.md').exists())

if __name__ == '__main__':
    unittest.main()
