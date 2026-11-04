"""Regressões para os dois diagnósticos fatais do Flutter Analyzer no APK 288.

Estes testes de fonte não substituem `flutter analyze`.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
DART = ROOT / 'lib/screens/map_monitoring_screen.dart'

class Build288FlutterAnalyze343Tests(unittest.TestCase):
    def test_initial_saved_route_guard_is_braced(self):
        source = DART.read_text(encoding='utf-8')
        match = re.search(r'void _tryOpenInitialSavedRoute\(\) \{(?P<body>.*?)\n  \}', source, re.S)
        self.assertIsNotNone(match)
        body = match.group('body')
        self.assertRegex(body, r'widget\.initialSavedRoute == null\) \{\s*return;\s*\}')
        self.assertNotRegex(body, r'widget\.initialSavedRoute == null\)\s*return;')

    def test_optional_cycling_route_uses_null_aware_collection_element(self):
        source = DART.read_text(encoding='utf-8')
        match = re.search(r'Future<void> _showBikeTripPlan\(\) async \{(?P<body>.*?)(?=\n  Future<|\n  void |\n  Widget |\n  @override)', source, re.S)
        self.assertIsNotNone(match)
        body = match.group('body')
        self.assertIn('<MapCyclingRoute>[?_cyclingRoute]', body)
        self.assertNotIn('if (_cyclingRoute != null) _cyclingRoute!', body)

    def test_version(self):
        self.assertIn('version: 1.0.345+345', (ROOT/'pubspec.yaml').read_text(encoding='utf8'))
        self.assertTrue((ROOT/'RELEASE-1.0.345.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.345.md').is_file())

if __name__ == '__main__':
    unittest.main()
