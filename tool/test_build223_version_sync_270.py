"""Guarda contra regressão de metadados obsoletos após o build 223."""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_FILES = (
    'pubspec.yaml', 'lib/core/app_metadata.dart', 'app_identity.json',
    'github-manager.json', 'test/app_metadata_test.dart', 'README.md',
    'CHANGELOG.md', 'ARCHITECTURE.md', 'VALIDATION.md',
    'lib/services/update_news_catalog.dart',
    'lib/services/map_cycling_route_service.dart',
    'lib/services/route_explorer_service.dart',
    'lib/services/offline_map_service.dart',
    'lib/widgets/map_navigation_3d_view.dart',
    'lib/services/map_weather_service.dart',
    'lib/services/map_destination_search_service.dart',
    'lib/screens/app_info_screen.dart',
    'lib/screens/app_info_screen_components.dart',
    'tool/check_version_sync.py',
)


class Build223VersionSyncTests(unittest.TestCase):
    def test_ci_delegates_version_code_to_dynamic_validator(self):
        script = (ROOT / 'tool/verify_project.sh').read_text(encoding='utf-8')
        self.assertIn('python3 tool/check_version_sync.py', script)
        self.assertNotRegex(script, r'grep\s+-q\s+[\'\"]\"versionCode\":\s*\d+')
        self.assertNotRegex(script, r"grep\s+-q\s+['\"]static const int build = \d+")
        self.assertNotRegex(script, r"grep\s+-q\s+['\"]\"build\": \d+")

    def test_validator_rejects_mismatched_android_version_code_and_name(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary)
            pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
            version_line = next(line for line in pubspec.splitlines() if line.startswith('version: '))
            version = version_line.split()[1].split('+')[0]
            for rel in (*VALIDATOR_FILES, f'RELEASE-{version}.md'):
                dest = target / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, dest)

            validator = target / 'tool/check_version_sync.py'

            def check():
                return subprocess.run(
                    [sys.executable, str(validator)],
                    cwd=target,
                    capture_output=True,
                    text=True,
                    check=False,
                )

            self.assertEqual(check().returncode, 0, 'Aligned version metadata should pass')
            manifest = target / 'github-manager.json'
            original = json.loads(manifest.read_text(encoding='utf-8'))
            corrupted_code = json.loads(json.dumps(original))
            corrupted_code['android']['versionCode'] = original['build'] - 1
            manifest.write_text(json.dumps(corrupted_code), encoding='utf-8')
            error = check()
            self.assertNotEqual(error.returncode, 0, 'Incorrect versionCode must fail')
            self.assertIn('android diverge', error.stdout + error.stderr)

            corrupted_name = json.loads(json.dumps(original))
            corrupted_name['android']['versionName'] = original['version'] + '.invalid'
            manifest.write_text(json.dumps(corrupted_name), encoding='utf-8')
            error = check()
            self.assertNotEqual(error.returncode, 0, 'Incorrect versionName must fail')
            self.assertIn('android diverge', error.stdout + error.stderr)


if __name__ == '__main__':
    unittest.main()
