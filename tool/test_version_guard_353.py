"""Prevent CI from pinning stale release numbers as in Android APK #300."""
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

class VersionGuard353Tests(unittest.TestCase):
    def test_verify_script_derives_active_version_from_pubspec(self):
        script=(ROOT/'tool/verify_project.sh').read_text('utf8')
        self.assertIn('release_full="$(sed -nE',script)
        self.assertIn('release_version="${release_full%%+*}"',script)
        self.assertIn('grep -Fxq "version: ${release_full}"',script)
        self.assertIn('grep -Fq "VigiaIA/${release_version}',script)
        release_files = ('pubspec.yaml', 'lib/core/app_metadata.dart',
                         'app_identity.json', 'github-manager.json',
                         'ARCHITECTURE.md', 'lib/services/map_destination_search_service.dart',
                         'lib/services/map_weather_service.dart',
                         'lib/services/map_cycling_route_service.dart',
                         'lib/services/route_explorer_service.dart')
        for line in script.splitlines():
            command = line.split('||', 1)[0]
            if ('grep ' in command and any(f in command for f in release_files)
                and ('version:' in command or 'VigiaIA/' in command
                     or 'String version' in command or '"version"' in command)):
                self.assertNotRegex(command, r'1\.0\.\d{3}', 'verificador exige uma versão numérica fixa')

    def test_release_version_is_greater_than_verified_base(self):
        from json import loads
        baseline=loads((ROOT/'tool/version_baseline.json').read_text('utf8'))
        expected=baseline['new_version']
        self.assertIn('version: '+expected,(ROOT/'pubspec.yaml').read_text('utf8'))
        self.assertLess(int(baseline['verified_latest_base'].split('+')[1]),int(expected.split('+')[1]))

if __name__=='__main__': unittest.main()
