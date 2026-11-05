"""APK 287: o teste Dart deve ler o pubspec; sem expectativa 1.0.xxx fixa."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class DynamicMetadata343(unittest.TestCase):
    def test_current_release_manifest_is_consistent(self):
        manifest = (ROOT / 'pubspec.yaml').read_text('utf-8')
        version = re.search(r'(?m)^version: (\d+\.\d+\.\d+)\+(\d+)$', manifest)
        self.assertIsNotNone(version)
        code = (ROOT / 'lib/core/app_metadata.dart').read_text('utf-8')
        self.assertIn(f"static const String version = '{version.group(1)}';", code)
        self.assertIn(f"static const int build = {version.group(2)};", code)

    def test_flutter_test_uses_pubspec_instead_of_hardcoded_release(self):
        test = (ROOT / 'test/app_metadata_test.dart').read_text('utf-8')
        self.assertIn("File('pubspec.yaml').readAsStringSync()", test)
        self.assertIn('expect(AppMetadata.version, match!.group(1));', test)
        self.assertIn('expect(AppMetadata.build, int.parse(match.group(2)!));', test)
        self.assertNotRegex(test, r"expect\(AppMetadata\.version,\s*'\d")
        self.assertNotRegex(test, r'expect\(AppMetadata\.build,\s*\d')

    def test_preventive_checker_runs_dynamic_guard(self):
        checker = (ROOT / 'tool/check_version_sync.py').read_text('utf-8')
        verify = (ROOT / 'tool/verify_project.sh').read_text('utf-8')
        self.assertIn('test/app_metadata_test.dart nao compara versao/build com pubspec.yaml', checker)
        self.assertIn('test_app_metadata_dynamic_342.py', verify)


if __name__ == '__main__':
    unittest.main()
