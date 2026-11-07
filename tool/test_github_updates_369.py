"""Regressões do falso atualizado visto com 1.0.367 instalada / 1.0.368 publicada."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return (ROOT / name).read_text('utf8')


class GitHubUpdater369(unittest.TestCase):
    def test_new_release_does_not_depend_on_eligible_apk(self):
        code = read('lib/services/github_release_update_service.dart')
        release_selection = code.split('static VigiaGitHubRelease? newest(', 1)[1].split('enum VigiaUpdateStatus', 1)[0]
        self.assertIn('Uri? downloadUrl;', code)
        self.assertIn('bool get hasDownloadableApk', code)
        self.assertIn('if (chosen == null || release.build > chosen.build) chosen = release;', release_selection)
        self.assertIn('final assets = entry[\'assets\'];', release_selection)
        self.assertIn('downloadUrl: downloadUrl,', release_selection)
        self.assertNotIn('if (assets is! List) continue;', release_selection)
        self.assertNotIn('if (size is! int ||', release_selection)

    def test_missing_unsafe_apk_not_allowed_to_download(self):
        service = read('lib/services/github_release_update_service.dart')
        ui = read('lib/screens/github_updates_screen.dart')
        self.assertIn('if (!release.hasDownloadableApk)', service)
        self.assertIn('if (release.downloadUrl == null)', ui)
        self.assertIn('Abrir Releases no GitHub', ui)
        self.assertIn('sha256.bind(pending.openRead()).first', service)
        self.assertIn('install()', ui)

    def test_large_universal_cap_matches_native_installer(self):
        service = read('lib/services/github_release_update_service.dart')
        self.assertIn('maxApkBytes = 600 * 1024 * 1024', service)
        for filename in ('tool/android/VigiaUpdateInstaller.kt',
                         'android/app/src/main/kotlin/com/vigiaia/app/VigiaUpdateInstaller.kt'):
            native = read(filename)
            self.assertIn('maxBytes = 600L * 1024L * 1024L', native)
            self.assertIn('archiveSignatures', native)
            self.assertIn('getPackageArchiveInfo', native)

    def test_dart_regressions_cover_reported_case(self):
        tests = read('test/github_release_update_test.dart')
        self.assertIn('versão nova sem APK universal não é confundida com atualizado', tests)
        self.assertIn('APK universal acima do limite não apaga detecção da nova versão', tests)
        self.assertIn('APK universal grande dentro do limite é aceito com SHA-256', tests)
        self.assertIn('1.0.367', tests)
        self.assertIn('1.0.368', tests)

    def test_version_sync(self):
        self.assertIn('version: 1.0.369+369', read('pubspec.yaml'))
        self.assertIn("version = '1.0.369'", read('lib/core/app_metadata.dart'))
        self.assertIn('build = 369', read('lib/core/app_metadata.dart'))
        self.assertTrue((ROOT / 'RELEASE-1.0.369.md').is_file())


if __name__ == '__main__':
    unittest.main()
