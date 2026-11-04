"""Protege o acesso único às integrações sem remover telas internas existentes."""
import re
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(name): return (ROOT/name).read_text(encoding='utf-8')

class ApiCentralization328Tests(unittest.TestCase):
    def test_settings_only_one_apis_entry(self):
        screen=read('lib/screens/settings_screen.dart')
        self.assertEqual(screen.count("title: 'Serviços e APIs'"), 1)
        self.assertNotIn("title: 'Gemini para Mapas'",screen)
        self.assertNotIn("title: 'Chave do Google Maps'",screen)
        self.assertNotIn('const GeminiMapSettingsScreen()',screen)
        self.assertNotIn('const GoogleMapsKeyScreen()',screen)
        self.assertIn('const ApiServicesSetupScreen()',screen)

    def test_map_panel_has_no_api_configuration_shortcut(self):
        screen=read('lib/screens/map_monitoring_screen.dart')
        panel=read('lib/widgets/map_layer_picker_panel.dart')
        self.assertIn('MapLayerPickerPanel(', screen)
        self.assertNotIn('ApiServicesSetupScreen',panel)
        self.assertNotIn("title: const Text('Serviços e APIs')",panel)
        self.assertIn('const ApiServicesSetupScreen()',read('lib/screens/settings_screen.dart'))

    def test_all_sensitive_key_screens_reachable_from_central(self):
        central=read('lib/screens/api_services_setup_screen.dart')
        for value in ('const GeminiMapSettingsScreen()', 'const GoogleMapsKeyScreen()',
                      'PartnerApiProvider.geoapify','PartnerApiProvider.openrouteservice',
                      'openStadiaKeyInitially: true', 'showApiServiceGuide(context)',
                      'ApiHelpProvider.openMeteo'):
            self.assertIn(value, central)
        assistant=read('lib/screens/gemini_map_assistant_screen.dart')
        self.assertIn('const ApiServicesSetupScreen()',assistant)
        self.assertNotIn('const GeminiMapSettingsScreen()',assistant)

    def test_release_increment(self):
        self.assertIn('version: 1.0.350+350',read('pubspec.yaml'))
        self.assertIn("static const int build = 350;",read('lib/core/app_metadata.dart'))
        self.assertTrue((ROOT/'RELEASE-1.0.348.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.348.md').is_file())

if __name__=='__main__': unittest.main()
