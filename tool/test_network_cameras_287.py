import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding='utf-8')

class NetworkAndMonitor287(unittest.TestCase):
    def test_lan_discovery_scoped_and_no_token(self):
        source = read('lib/services/lan_camera_discovery_service.dart')
        transmitter = read('android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt')
        assert 'RawDatagramSocket.bind' in source
        assert 'WS-Discovery' in source and 'ProbeMatches' in source
        assert 'LanCameraKind.vigiaIa' in source
        assert "_vigiaProbe = 'VIGIAIA_DISCOVER_V1'" in source
        assert 'VIGIAIA_HERE_V1' in transmitter
        assert 'token' not in transmitter.split('val response = "VIGIAIA_HERE_V1|$model"')[1].split('socket.send',1)[0]
        assert 'try { discoverySocket?.close() }' in transmitter
        assert (ROOT/'tool/android/native_transmitter/PhoneCameraServer.kt').read_bytes() == (ROOT/'android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt').read_bytes()

    def test_pairing_still_requires_qr(self):
        ui = read('lib/screens/multi_camera_screen.dart') + read('lib/screens/multi_camera_screen_lan_discovery.dart')
        assert 'onScanNetwork: _scanLocalNetwork' in ui
        assert 'await _scanPhoneQr()' in ui
        assert 'pareamento via QR necessário' in ui
        assert 'LanCameraKind.vigiaIa' in ui
        assert 'initialAddress:' in ui

    def test_rtsp_credentials_protected(self):
        ui = read('lib/screens/multi_camera_screen_editor.dart')
        store = read('lib/services/camera_registry_service.dart')
        assert 'obscureText: !passwordVisible' in ui
        assert "text: previousCredentials.isNotEmpty" in ui
        assert "uri.replace(userInfo: '$usernameValue:$passwordValue')" in ui
        assert "uri.userInfo.isEmpty && uri.path.isNotEmpty" in ui
        assert "map['addressSecret'] = await _native.protectSecret" in store
        assert "map['address'] = null" in store

    def test_fullscreen_rotation_and_controls(self):
        ui = read('lib/screens/monitor_screen_fullscreen.dart')
        assert 'AppOrientationService.allowTransmissionRotation()' in ui
        assert 'AppOrientationService.lockPortrait()' in ui
        assert '_showFullscreenRemoteControls()' in ui
        assert 'McrpLiveRemoteControls(liveUrl: url)' in ui
        assert "_fullscreenQuickCommand('photo')" in ui
        assert "_fullscreenQuickCommand('record/toggle')" in ui
        assert 'ThemeData.dark' in ui

    def test_heuristic_opt_in_and_model_visible(self):
        controller = read('lib/controllers/monitor_controller.dart') + read('lib/controllers/monitor_controller_state_support.dart')
        full = read('lib/screens/monitor_screen_fullscreen.dart')
        hud = read('lib/screens/monitor_screen_components.dart')
        assert 'bool _partialPersonHintsEnabled = false;' in controller
        assert '_partialPersonHintsEnabled && _alertLabels.contains' in controller
        assert 'setPartialPersonHintsEnabled' in controller
        remote = read('lib/widgets/mcrp_remote_controls.dart')
        assert 'Icons.face_outlined' in remote and 'possível pessoa (experimental)' in remote
        assert 'deviceModel' in hud and "? '$detectedModel · Ao vivo'" in hud

if __name__ == '__main__':
    unittest.main()
