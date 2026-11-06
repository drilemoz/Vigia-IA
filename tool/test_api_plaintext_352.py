from tool.release_version_checks import current_release, version_only, catalog_reference, current_build
"""Contratos de interface/backup .env; não substituem Flutter analyze nem teste Android."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]

def src(p): return (ROOT/p).read_text('utf8')

class Plaintext352Tests(unittest.TestCase):
    def test_version_is_next_after_verified_base(self):
        self.assertIn('version: ' + current_release(ROOT),src('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.353.md').exists())
        self.assertTrue((ROOT/'RELEASE-1.0.352.md').exists())
    def test_google_action_row(self):
        a=src('lib/screens/google_maps_key_screen.dart')
        self.assertIn('Row(children: [',a)
        for t in ['Colar','Copiar','Verificar configuração', 'Icons.fact_check_outlined']:
            self.assertIn(t,a)
        self.assertIn('userConfigured',a)
    def test_registered_keys_view(self):
        a=src('lib/screens/registered_api_keys_screen.dart')
        for t in ['Google Gemini','Google Maps (chave salva)','Stadia Maps','Geoapify',
                  'OpenRouteService','Open-Meteo','_showOrHide','_copy','SelectableText']:
            self.assertIn(t,a)
        self.assertIn('Google Maps SDK (chave do APK)',a)
    def test_plaintext_archive_and_import(self):
        api=src('lib/services/api_credentials_backup_service.dart')
        ui=src('lib/screens/api_services_setup_screen.dart')
        for t in ['exportPlaintextEnv','selectPlaintextEnv','parsePlaintextEnv',
                  'GEMINI_API_KEY','STADIA_API_KEY','GOOGLE_MAPS_USER_API_KEY',
                  'GEOAPIFY_API_KEY','OPENROUTESERVICE_API_KEY',
                  "mimeType: 'text/plain'", "fileName: 'vigiaia-apis-$date.env'", 
                  'keys.containsKey','selectAndDecrypt']:
            self.assertIn(t,api)
        self.assertIn('Ver APIs e chaves cadastradas',ui)
        self.assertIn('_transferPlaintextKeys(exporting: true)',ui)
        self.assertIn('_transferPlaintextKeys(exporting: false)',ui)
        self.assertIn('Importar backup antigo (.vigiaapis)',ui)
        self.assertIn('sem senha nem criptografia',ui)
        self.assertIn('Confirmar importação',ui)
        self.assertIn('api_credentials_plaintext_test.dart', '\n'.join(str(p) for p in (ROOT/'test').glob('*.dart')))
    def test_native_picker_short_plaintext_file(self):
        original=src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertEqual(original,src('tool/android/MainActivity.kt'))
        self.assertIn('require(bytes.isNotEmpty())',original)
        self.assertIn('beginApiArchiveImport',original)

if __name__=='__main__': unittest.main()
