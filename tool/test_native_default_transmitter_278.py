"""Verifica que o motor nativo é o único transmissor exposto na UI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def read(name):
    return (ROOT / name).read_text(encoding='utf-8')

class NativeTransmitterDefault278(unittest.TestCase):
    def test_all_entrypoints_use_native_transmitter(self):
        for name in ('lib/app/app.dart','lib/screens/launch_mode_screen.dart',
                     'lib/screens/settings_screen.dart', 'lib/screens/home_screen.dart', 'lib/screens/home_screen_redesign.dart'):
            source = read(name)
            if name != 'lib/screens/home_screen.dart':
                self.assertIn('NativeTransmitterScreen()',source, name)
            else:
                self.assertIn("native_transmitter_screen.dart",source)
            self.assertNotIn('CameraModeScreen()',source, name)
            if name != 'lib/screens/home_screen_redesign.dart':
                self.assertNotIn("camera_mode_screen.dart",source, name)

    def test_keeps_private_qr_remote_rec_and_emergency_controls(self):
        s=read('lib/screens/native_transmitter_screen.dart')
        for value in ("'Vigia IA · transmissor'", "'Controles locais de emergência'",
                      "'Parear outro celular'", 'McrpAddress.parse(url)',
                      'NativeCameraTransmitterService.start()',
                      'NativeCameraTransmitterService.stop()',
                      "'Alterar modo'", 'QrImageView(data: url'):
            self.assertIn(value,s)
        self.assertNotIn('CameraPreview(',s)
        self.assertNotIn('O modo Flutter anterior permanece disponível',s)

    def test_registration_names_are_consistent(self):
        monitor=read('lib/screens/monitor_connect_screen.dart')
        multicam=read('lib/screens/multi_camera_screen.dart')
        self.assertIn("displayName: _pairedCameraName ?? 'Câmera remota'",monitor)
        self.assertIn("_pairedCameraName = pairing.name",monitor)
        self.assertIn("'Câmera remota'",multicam)
        self.assertNotIn("'Câmera remota / celular'",multicam)
        self.assertIn("MinhaCameraLiveUrl.isValid(address)",monitor)
        # O protocolo e o token /live/ privado continuam compatíveis.
        self.assertIn('QrImageView(data: url',read('lib/screens/native_transmitter_screen.dart'))
        self.assertIn('record/start',read('lib/services/mcrp_client.dart'))

if __name__=='__main__': unittest.main()
