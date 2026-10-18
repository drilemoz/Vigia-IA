"""Testes estaticos da nova UI e preferencias; nao substituem Flutter/Android."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def source(path): return (ROOT / path).read_text(encoding='utf-8')

class TransmitterRedesign283(unittest.TestCase):
    def test_qr_modal_and_private_protocol_preserved(self):
        ui = source('lib/screens/native_transmitter_screen.dart')
        mcrp = source('lib/services/mcrp_client.dart')
        self.assertIn("'Vigia IA · Transmissão'", ui)
        self.assertIn('Icons.qr_code_2_rounded', ui)
        self.assertIn('showDialog<void>(', ui)
        self.assertIn('QrImageView(', ui)
        self.assertIn('data: url,', ui)
        self.assertIn('QrErrorCorrectLevel.H', ui)
        self.assertIn("'Vigia IA'", ui)
        self.assertIn("'Copiar endereço privado'", ui)
        self.assertNotIn('ExpansionTile(', ui)
        self.assertIn('^/live/[0-9a-f]{32}$', mcrp)
        self.assertIn('McrpAddress.parse(url)', ui)

    def test_actions_preserve_native_service_and_recording_status(self):
        ui = source('lib/screens/native_transmitter_screen.dart')
        for phrase in ("'Controles locais'", 'NativeCameraTransmitterService.toggleRecording()',
                       'NativeCameraTransmitterService.start()', 'NativeCameraTransmitterService.stop()',
                       "_command('photo')", "'camera/back'", "'camera/front'", "'eco/enable'",
                       "'eco/disable'", "'fps/5'", "'fps/10'", "'quality/480'",
                       "'quality/720'", "'torch/30'", "'torch/off'",
                       "'x-recording-seconds'", "'TRANSMITINDO'", "'GRAVANDO'",
                       'didChangeAppLifecycleState', '_showOptions(', '_controls('):
            self.assertIn(phrase, ui)
        self.assertNotIn('CameraPreview(', ui)
        self.assertNotIn('Image.memory(', ui)
        self.assertNotIn('SelectableText(url', ui)

    def test_first_install_follows_android_saved_choice_preserved(self):
        s=source('lib/services/appearance_settings_service.dart')
        self.assertIn('AppThemePreference _themePreference = AppThemePreference.system;',s)
        self.assertIn('orElse: () => AppThemePreference.system',s)
        self.assertIn('_themePreference = AppThemePreference.system;',s)
        self.assertIn('AppThemePreference.dark => ThemeMode.dark',s)
        self.assertIn('AppThemePreference.light => ThemeMode.light',s)
        self.assertIn("final themeName = map['theme'] as String?;",s)
        self.assertIn('await file.exists()',s)
        self.assertIn('ThemeMode.system',s)

if __name__=='__main__': unittest.main()
