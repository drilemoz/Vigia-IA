"""Regression GitHub updater ported from Uai Cortes; syntax/contract only, not Android build."""
import json
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def read(path):return (ROOT/path).read_text('utf8')

class GithubUpdater367(unittest.TestCase):
    def test_release_policy_strict(self):
        source=read('lib/services/github_release_update_service.dart')
        for token in ['drilemoz/Vigia-IA','VigiaIA-v$version+$build-universal.apk',
            'entry[\'draft\'] == true', "asset['state'] != 'uploaded'", 'browser_download_url',
            'expectedUrl.pathSegments', 'sha256.bind(pending.openRead()).first',
            'maxResponseBytes', 'maxApkBytes', 'cancelDownload', 'DateTime? _lastAutomaticCheck']:
            self.assertIn(token,source)
        self.assertNotIn('Authorization',source)
        self.assertNotIn('access_token',source)

    def test_manual_ux_and_automatic_check(self):
        app=read('lib/app/app.dart');about=read('lib/screens/app_info_screen_components.dart')
        ui=read('lib/screens/github_updates_screen.dart')
        self.assertIn('WidgetsBindingObserver',app)
        self.assertIn('AppLifecycleState.resumed',app)
        self.assertIn('checkOnForeground',app)
        self.assertIn('Atualização disponível',app)
        self.assertIn("Text('Verificar atualizações')",about)
        for token in ('Baixar atualização','Cancelar download','Instalar atualização',
                      'Abrir Releases no GitHub','_updates.install()', 'Verificar atualizações',
                      'showDialog<bool>'):
            self.assertIn(token,ui)

    def test_install_checks_identity_signature(self):
        installer=read('android/app/src/main/kotlin/com/vigiaia/app/VigiaUpdateInstaller.kt')
        for token in ('cacheDir','getPackageArchiveInfo', 'packageName != activity.packageName',
                      'archive.longVersionCode != expectedBuild', 'expectedBuild <= installed.longVersionCode',
                      'archiveSignatures', 'installedSignatures','SHA-256','canRequestPackageInstalls',
                      'FileProvider.getUriForFile','FLAG_GRANT_READ_URI_PERMISSION'):
            self.assertIn(token,installer)
        self.assertNotIn('ACTION_DELETE',installer)
        self.assertNotIn('ACTION_UNINSTALL_PACKAGE',installer)

    def test_android_manifest_and_channel(self):
        manifest=read('android/app/src/main/AndroidManifest.xml')
        self.assertIn('REQUEST_INSTALL_PACKAGES',manifest)
        self.assertIn('${applicationId}.updates',manifest)
        self.assertIn('@xml/vigia_update_file_paths',manifest)
        self.assertIn('vigiaia/updates',read('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt'))
        self.assertEqual(read('tool/android/VigiaUpdateInstaller.kt'), read('android/app/src/main/kotlin/com/vigiaia/app/VigiaUpdateInstaller.kt'))
        self.assertEqual(read('tool/android/vigia_update_file_paths.xml'), read('android/app/src/main/res/xml/vigia_update_file_paths.xml'))
        bootstrap = read('tool/bootstrap_android.sh')
        self.assertIn('cp "$ROOT/tool/android/VigiaUpdateInstaller.kt"',bootstrap)
        self.assertIn('cp "$ROOT/tool/android/vigia_update_file_paths.xml"',bootstrap)
        self.assertIn('path="updates/"',read('android/app/src/main/res/xml/vigia_update_file_paths.xml'))

    def test_current_build_and_no_automatic_install(self):
        self.assertIn('version: 1.0.367+367',read('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.367.md').is_file())
        service=read('lib/services/github_release_update_service.dart')
        method=re.search(r'Future<VigiaGitHubRelease\?> checkOnForeground\(\) async \{(.*?)\n  \}',service,re.S)
        self.assertIsNotNone(method)
        self.assertNotIn('download(',method.group(1))
        self.assertNotIn('install(',method.group(1))
        self.assertIn('GitHub Releases',read('RELEASE-1.0.367.md'))

if __name__=='__main__':unittest.main()
