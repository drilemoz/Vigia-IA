"""Contrato da interface compacta e confirmação de REC (sem substituir Flutter Test)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def read(relative):
    return (ROOT / relative).read_text(encoding='utf8')

class TransmitterRemoteRec276(unittest.TestCase):
    def test_native_screen_removes_preview_and_folds_sensitive_pairing(self):
        ui = read('lib/screens/native_transmitter_screen.dart')
        self.assertIn("'Vigia IA · transmissor'", ui)
        self.assertIn("'Transmissão ativa'", ui)
        self.assertIn("'Parear outro celular'", ui)
        self.assertIn("'Controles locais de emergência'", ui)
        self.assertIn("'REC ativo'", ui)
        self.assertIn('QrImageView(data: url', ui)
        self.assertIn('ExpansionTile(', ui)
        self.assertNotIn('CameraPreview(', ui)
        self.assertNotIn('Image.memory(', ui)
        self.assertNotIn('SelectableText(url', ui)
        self.assertIn('NativeCameraTransmitterService.stop()', ui)
        self.assertIn('McrpClient(McrpAddress.parse(url))', ui)

    def test_remote_rec_has_explicit_start_stop_and_rechecks_actual_status(self):
        panel = read('lib/widgets/mcrp_remote_controls.dart')
        client = read('lib/services/mcrp_client.dart')
        server = read('android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt')
        self.assertIn("'record/start'", panel)
        self.assertIn("'record/stop'", panel)
        self.assertIn("final state = await client.status();", panel)
        self.assertIn("state['x-recording'] == expectedRecording", panel)
        self.assertIn('var sent = false;', panel)
        self.assertIn('REC: estado desconhecido durante a desconexão.', panel)
        self.assertIn('Uma gravação ativa', panel)
        self.assertIn("'x-recording'", client)
        self.assertIn('await _http.postUrl(uri)', client)
        self.assertIn('X-Recording:', server)
        self.assertIn('POST $control/record/start HTTP/1.1', server)
        self.assertIn('POST $control/record/stop HTTP/1.1', server)
        self.assertNotIn("await client.command(action);\n      await client.command(action);", panel)

    def test_display_identity_does_not_break_old_mcrp_url_protocol(self):
        self.assertIn("name: 'Câmera remota'", read('lib/services/remote_camera_pairing_service.dart'))
        self.assertIn("name: 'Câmera remota'", read('lib/services/minha_camera_telemetry.dart'))
        self.assertIn("'Controle remoto · ${_status", read('lib/widgets/mcrp_remote_controls.dart'))
        self.assertIn('MinhaCameraLiveUrl.isValid(url)', read('lib/screens/monitor_screen_mcrp_support.dart'))
        self.assertIn("^/live/[0-9a-f]{32}$", read('lib/services/mcrp_client.dart'))
        self.assertIn("'1.0.276'", read('lib/core/app_metadata.dart'))

if __name__ == '__main__':
    unittest.main()
