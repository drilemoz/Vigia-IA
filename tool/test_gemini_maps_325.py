"""Contratos estáticos da integração opcional Gemini sem vazamento de chave."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def source(name): return (ROOT/name).read_text('utf-8')

class GeminiMaps325(unittest.TestCase):
    def test_credentials_are_native_keystore_backed(self):
        native=source('tool/android/MainActivity.kt')
        for text in ('geminiKeyStatus','saveGeminiApiKey','revealGeminiApiKey','protectSecret(value)',
                     'unprotectSecret(encrypted)', 'vigiaia_gemini_private'):
            self.assertIn(text,native)
        self.assertEqual(native,source('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt'))
        for s in ('tool/android/gemini_backup_rules.xml','tool/android/gemini_data_extraction_rules.xml'):
            self.assertIn('vigiaia_gemini_private.xml',source(s))
        self.assertIn('gemini_backup_rules.xml',source('tool/bootstrap_android.sh'))
    def test_rest_search_keeps_verified_locations(self):
        svc=source('lib/services/gemini_map_service.dart')
        ui=source('lib/screens/gemini_map_assistant_screen.dart')
        self.assertIn("'x-goog-api-key'",svc)
        self.assertNotIn('?key=',svc)
        self.assertIn('responseMimeType',svc)
        self.assertIn('GeminiMapSuggestion.parse',svc)
        self.assertIn('_search.searchSubmitted(',ui)
        self.assertIn('_places = _search.results',ui)
        self.assertIn('Navigator.of(context).pop(place)',ui)
        self.assertNotIn('MapDestinationSearchResult(',ui) # sem locais inventados
    def test_actions_are_wired(self):
        settings=source('lib/screens/gemini_map_settings_screen.dart')
        maps=source('lib/screens/map_monitoring_screen.dart')
        for text in ('Salvar','Colar','Copiar','Remover','Testar conexão Gemini','Mostrar chave','Ocultar chave'):
            self.assertIn(text,settings)
        self.assertIn('GeminiMapService.instance.status()',maps)
        self.assertIn('.interpret(typed)',maps)
        self.assertIn('Gemini indisponível. Pesquisa normal ativada.',maps)
        self.assertIn('const ApiServicesSetupScreen()',source('lib/screens/settings_screen.dart'))
        self.assertIn('const GeminiMapSettingsScreen()', source('lib/screens/api_services_setup_screen.dart'))
    def test_version(self):
        self.assertIn('version: 1.0.330+330',source('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.330.md').exists())
        self.assertIn("build: 330",source('lib/services/update_news_catalog.dart'))
if __name__=='__main__':unittest.main()
