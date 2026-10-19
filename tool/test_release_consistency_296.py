import unittest
from pathlib import Path
from unittest.mock import patch
import tempfile
import shutil
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_release_consistency as checks


class ReleaseConsistency296Tests(unittest.TestCase):
    def test_current_metadata_and_catalog_match_pubspec(self):
        checks.validate()

    def test_reject_stale_catalog_build(self):
        # Inspect a temporary project copy so tests never modify source files.
        real_root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp)
            paths = ('pubspec.yaml', 'lib/core/app_metadata.dart',
                     'lib/services/update_news_catalog.dart',
                     'lib/screens/app_info_screen_components.dart',
                     'app_identity.json', 'github-manager.json',
                     'tool/verify_project.sh', 'RELEASE-1.0.296.md')
            for name in paths:
                target = dest / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(real_root / name, target)
            catalog = dest / 'lib/services/update_news_catalog.dart'
            current = catalog.read_text('utf-8')
            self.assertEqual(current.count("AppBuildVersion(version: '1.0.296', build: 296)"), 2)
            catalog.write_text(current.replace('build: 296', 'build: 295', 1), 'utf-8')
            with patch.object(checks, 'ROOT', dest), self.assertRaisesRegex(ValueError, 'Catalogo de Novidades'):
                checks.validate()

    def test_reject_android_metadata_mismatch(self):
        # Validate that version mismatch in standalone metadata is detectable.
        source = Path(__file__).resolve().parents[1] / 'github-manager.json'
        data = __import__('json').loads(source.read_text('utf-8'))
        self.assertEqual(data['version'], '1.0.296')
        self.assertEqual(data['android']['versionCode'], 296)
