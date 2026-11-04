import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text('utf-8')

class ApiServices327Tests(unittest.TestCase):
    def test_six_services_and_help(self):
        setup = read('lib/screens/api_services_setup_screen.dart')
        for required in ('Google Gemini','Google Maps Platform','Stadia Maps',
                         'Geoapify','OpenRouteService','Open-Meteo',
                         'showApiServiceGuide(context)', 'showApiServiceHelp(context,',
                         'PartnerApiKeyScreen', 'initialSetup = false', 'markOnboardingCompleted()'):
            self.assertIn(required,setup)
        help = read('lib/screens/api_service_help.dart')
        for required in ('ApiHelpProvider.gemini','ApiHelpProvider.googleMaps',
                         'ApiHelpProvider.stadia','ApiHelpProvider.geoapify',
                         'ApiHelpProvider.openrouteservice','ApiHelpProvider.openMeteo',
                         'Sem chave', 'https://account.heigit.org/', 'Testar previsão'):
            self.assertIn(required,help)

    def test_partner_provider_is_whitelisted_encrypted_and_not_backed_up(self):
        native = read('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertEqual(native,read('tool/android/MainActivity.kt'))
        for required in ('"partnerApiKeyStatus"', '"savePartnerApiKey"',
                         '"revealPartnerApiKey"', 'private fun partnerProvider(',
                         '"geoapify" -> "geoapify"', '"openrouteservice" -> "openrouteservice"',
                         'protectSecret(value)', 'unprotectSecret(encrypted)',
                         'vigiaia_partner_api_private', 'editor.commit()'):
            self.assertIn(required,native)
        for name in ('gemini_backup_rules.xml','gemini_data_extraction_rules.xml'):
            rules=read('android/app/src/main/res/xml/'+name)
            for path in ('vigiaia_gemini_private.xml', 'vigiaia_google_maps.xml',
                         'vigiaia_partner_api_private.xml'):
                self.assertIn(path,rules)
        self.assertEqual(read('android/app/src/main/res/xml/gemini_data_extraction_rules.xml').count('vigiaia_partner_api_private.xml'),2)

    def test_keys_are_only_sent_after_explicit_action(self):
        service=read('lib/services/partner_api_key_service.dart')
        screen=read('lib/screens/partner_api_key_screen.dart')
        self.assertIn("'api.openrouteservice.org', '/v2/directions/cycling-regular'",service)
        self.assertIn("'api.geoapify.com', '/v1/geocode/search'",service)
        self.assertIn("request.followRedirects = false",service)
        self.assertIn('Future<String> test(PartnerApiProvider provider)',service)
        self.assertIn('_service.test(widget.provider)',screen)
        self.assertIn('PartnerApiKeyService.validate(_controller.text)',screen)
        self.assertIn('Remover chave $_title?',screen)
        self.assertIn("_service.save(widget.provider, '')",screen)

    def test_google_maps_does_not_fake_network_validation(self):
        screen=read('lib/screens/google_maps_key_screen.dart')
        self.assertIn('O Maps SDK for Android valida a chave',screen)
        self.assertIn('Verificar configuração',screen)
        self.assertIn('Clipboard.getData',screen)
        self.assertIn('Clipboard.setData',screen)
        self.assertIn('showApiServiceHelp(context, ApiHelpProvider.googleMaps)',screen)

    def test_version(self):
        self.assertIn('version: 1.0.347+347',read('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.347.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.347.md').is_file())

if __name__ == '__main__': unittest.main()
