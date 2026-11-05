"""Contratos estruturais do seletor único de camadas (não substitui Flutter test)."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]

def read(s): return (R/s).read_text('utf-8')

class MapLayerPicker347(unittest.TestCase):
    def test_dialog_has_tabs_and_confirmed_selection(self):
        picker=read('lib/widgets/map_layer_picker_panel.dart')
        screen=read('lib/screens/map_monitoring_screen.dart')
        for token in ('layer-tab-', 'layer-choice-', 'Selecionado:', 'Cancelar', "child: const Text('OK')", 'MapAppearancePreset.values', 'MapStylePreset.values', 'MapProvider.values'):
            self.assertIn(token,picker)
        self.assertIn('showMapCenteredDialog<MapLayerPickerSelection>',screen)
        self.assertIn('if (selected == null || !mounted) return;',screen)
        self.assertIn('await _mapViewSettings.setStylePreset(selected.stylePreset);',screen)
        self.assertIn('await _mapViewSettings.setProvider(selected.provider);',screen)
        self.assertIn('MapLayerPickerPanel(',screen)

    def test_api_management_stays_in_settings(self):
        picker=read('lib/widgets/map_layer_picker_panel.dart')
        settings=read('lib/screens/settings_screen.dart')
        self.assertNotIn('ApiServicesSetupScreen',picker)
        self.assertNotIn("const Text('Serviços e APIs')",picker)
        self.assertIn("title: 'Serviços e APIs'",settings)
        self.assertIn('const ApiServicesSetupScreen()',settings)

    def test_disabled_styles_and_google_key_gate(self):
        picker=read('lib/widgets/map_layer_picker_panel.dart')
        for token in ('!widget.googleSdkConfigured', 'widget.stadiaConfigured', 'MapProvider.google', 'MapStylePreset.topographic', 'widget.onCancel', 'widget.onConfirm'):
            self.assertIn(token,picker)
        widget_test=read('test/map_layer_picker_panel_test.dart')
        self.assertEqual(widget_test.count('testWidgets('),4)

    def test_version(self):
        self.assertIn('version: 1.0.351+351',read('pubspec.yaml'))
        self.assertTrue((R/'RELEASE-1.0.348.md').is_file())
        self.assertTrue((R/'VALIDATION-1.0.348.md').is_file())

if __name__=='__main__': unittest.main()
