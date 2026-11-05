"""Map SDK: do not mistake a locally saved key for an authenticated APK."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def src(rel):
    return (ROOT / rel).read_text(encoding='utf-8')

class MapsSdkBuildKey333Tests(unittest.TestCase):
    def test_optional_secret_reaches_manifest_through_gradle(self):
        workflow = src('.github/workflows/android-apk.yml')
        gradle = src('android/app/build.gradle.kts')
        manifest = src('android/app/src/main/AndroidManifest.xml')
        self.assertIn('MAPS_API_KEY: ${{ secrets.MAPS_API_KEY }}', workflow)
        self.assertIn('System.getenv("MAPS_API_KEY")', gradle)
        self.assertIn('localProperties.getProperty("MAPS_API_KEY", "")', gradle)
        self.assertIn('manifestPlaceholders["MAPS_API_KEY"] = googleMapsApiKey', gradle)
        self.assertIn('android:value="${MAPS_API_KEY}"', manifest)
        self.assertNotIn('echo "$MAPS_API_KEY"', workflow)
        self.assertNotIn('MAPS_API_KEY=AIza', workflow)
    def test_no_dynamic_manifest_mutation(self):
        native = src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertEqual(native, src('tool/android/MainActivity.kt'))
        self.assertNotIn('injectGoogleMapsKey(', native)
        self.assertNotIn('applyStoredGoogleMapsKey(', native)
        self.assertNotIn('metaData?.putString(googleMapsMetaName', native)
        self.assertIn('"sdkReady" to (buildKey != null)', native)
        self.assertIn('"userConfigured" to (userKey != null)', native)
        self.assertIn('protectSecret(value)', native)
        self.assertIn('unprotectSecret(stored)', native)
    def test_map_requires_sdk_ready(self):
        service = src('lib/services/google_maps_key_service.dart')
        screen = src('lib/screens/map_monitoring_screen.dart')
        self.assertIn('bool get hasKey => _status.sdkReady;', service)
        self.assertIn('sdkReady: data[\'sdkReady\'] == true', service)
        self.assertIn('sdkConfigured: GoogleMapsKeyService.instance.hasKey,', screen)
        self.assertIn('OfflineMapRenderPolicy.useGoogleRenderer(', screen)
        self.assertIn('!GoogleMapsKeyService.instance.hasKey', screen)
    def test_central_distinguishes_six_integrations(self):
        central = src('lib/screens/api_services_setup_screen.dart')
        for term in ('Google Gemini','Google Maps Platform','Stadia Maps','Geoapify',
                     'OpenRouteService', 'Open-Meteo', 'chave salva', 'sdkReady',
                     'Busca de destinos e alternativa de pontos próximos online', 'não exige chave'):
            self.assertIn(term, central)
        config = src('lib/screens/google_maps_key_screen.dart')
        self.assertIn('O Maps SDK for Android valida a chave', config)
        self.assertIn('MAPS_API_KEY', config)
        self.assertIn('não é injetada no SDK', config)
    def test_version(self):
        self.assertIn('version: 1.0.353+353', src('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.348.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.348.md').is_file())

if __name__ == '__main__':
    unittest.main()
