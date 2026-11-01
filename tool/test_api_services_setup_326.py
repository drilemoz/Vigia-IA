import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def src(file):
    return (ROOT / file).read_text(encoding='utf8')

class ApiServicesSetup326Tests(unittest.TestCase):
    def test_permission_step_precedes_api_step_and_onboarding_is_deferred(self):
        permission = src('lib/screens/access_guide_screen.dart')
        setup = src('lib/screens/api_services_setup_screen.dart')
        self.assertIn('markPermissionsReviewed()', permission)
        self.assertIn('ApiServicesSetupScreen(', permission)
        self.assertNotIn('markOnboardingCompleted()', permission)
        self.assertIn('markOnboardingCompleted()', setup)
        self.assertIn('LaunchModeScreen(', setup)
        self.assertLess(setup.index('markOnboardingCompleted()'), setup.index('LaunchModeScreen('))
        self.assertIn('Configurar depois', setup)

    def test_restart_restores_pending_step_without_retriggering_on_updates(self):
        app = src('lib/app/app.dart')
        setup = src('lib/screens/api_services_setup_screen.dart')
        self.assertIn('apiSetupPending', app)
        self.assertIn('if (_apiSetupPending)', app)
        self.assertIn('ApiServicesSetupScreen(initialSetup: true)', app)
        self.assertIn('if (completed)', app)
        self.assertIn('initialSetup = false', setup)
        for path in ('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt',
                     'tool/android/MainActivity.kt'):
            native=src(path)
            for marker in ('apiSetupPending', 'markPermissionsReviewed', 'api_setup_pending_v1',
                           'noBackupFilesDir', 'apiSetupMarkerFile().delete()'):
                self.assertIn(marker,native)
        self.assertEqual(src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt'),
                         src('tool/android/MainActivity.kt'))

    def test_three_optional_services_reuse_existing_credentials_screens(self):
        setup=src('lib/screens/api_services_setup_screen.dart')
        for term in ('GeminiMapSettingsScreen', 'GoogleMapsKeyScreen', 'showOfflineMapManager',
                     'openStadiaKeyInitially: true',
                     'OpenStreetMap', 'Sem chave', 'Gerenciar chave', 'Geoapify', 'OpenRouteService', 'Open-Meteo'):
            # Case for status label 'Sem chave'
            self.assertIn(term,setup)
        offline=src('lib/widgets/offline_map_manager_sheet.dart')
        self.assertIn('openStadiaKeyInitially',offline)
        self.assertIn('if (mounted) unawaited(_configureStadiaKey())',offline)
        self.assertIn('ApiServicesSetupScreen()',src('lib/screens/settings_screen.dart'))
        gemini=src('lib/screens/gemini_map_settings_screen.dart')
        self.assertIn('https://aistudio.google.com/apikey',gemini)
        help_screen=src('lib/screens/api_service_help.dart')
        for url in ('https://aistudio.google.com/apikey',
                    'https://console.cloud.google.com/google/maps-apis',
                    'https://client.stadiamaps.com/dashboard/'):
            self.assertIn(url, help_screen)
        self.assertNotIn('gemini_api_key=', setup)

    def test_version_and_documentation(self):
        self.assertIn('version: 1.0.327+327',src('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.327.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.327.md').is_file())

if __name__ == '__main__': unittest.main()
