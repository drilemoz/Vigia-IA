from tool.release_version_checks import current_release, version_only, catalog_reference, current_build
"""Contratos da otimização em segundo plano e da modularização (1.0.349).

O teste estático não substitui flutter analyze/test nem medição de energia.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(name):
    return (ROOT / name).read_text(encoding='utf-8')


class MapBackgroundRefactor349(unittest.TestCase):
    def test_hud_starts_and_stops_with_lifecycle(self):
        screen = read('lib/screens/map_monitoring_screen.dart')
        policy = read('lib/services/map_hud_refresh_policy.dart')
        self.assertIn('_appActive = _appLifecycleResumed && widget.workspaceVisible;', screen)
        self.assertIn('void _startHudTimer()', screen)
        self.assertIn('void _stopHudTimer()', screen)
        self.assertIn('if (!_appActive || _hudTimer != null) return;', screen)
        self.assertIn('if (!mounted || !_appActive) return;', screen)
        self.assertGreaterEqual(screen.count('_startHudTimer();'), 3)
        self.assertGreaterEqual(screen.count('_stopHudTimer();'), 3)
        self.assertIn('MapHudRefreshPolicy.evaluate(', screen)
        self.assertIn('staleProgress || refreshDevice', policy)
        self.assertIn('MapHudRefreshPolicy.tickInterval', screen)
        self.assertIn('if (decision.clearStaleProgress)', screen)
        self.assertIn('if (decision.rebuildMap)', screen)
        self.assertIn('if (decision.refreshDevice)', screen)
        self.assertNotIn('_hudTimer = Timer.periodic(const Duration(seconds: 10)', screen)

    def test_compass_and_telemetry_do_not_run_hidden(self):
        screen = read('lib/screens/map_monitoring_screen.dart')
        start = screen.split('void _startCompassListener() {', 1)[1].split('\n  }', 1)[0]
        self.assertIn('if (!_appActive) return;', start)
        self.assertIn('final oldCompass = _compassSubscription;', screen)
        self.assertIn('if (oldCompass != null) unawaited(oldCompass.cancel());', screen)
        self.assertIn('if (!mounted || !_appActive ||', screen)
        self.assertIn('telemetry.batteryPercent == _phoneBattery', screen)
        self.assertIn('state == _radioState', screen)

    def test_camera_policy_keeps_source_identity_and_credentials(self):
        screen = read('lib/screens/map_monitoring_screen.dart')
        policy = read('lib/services/map_camera_source_policy.dart')
        self.assertIn('MapCameraSourcePolicy.fromEndpoint(camera)', screen)
        self.assertIn('MapCameraSourcePolicy.representsSameSource(first, second)', screen)
        for token in ('CameraEndpointType.local', 'CameraEndpointType.rtsp',
                      'CameraEndpointType.esp32', 'CameraEndpointType.remotePhone',
                      'remoteAccessKey: camera.accessKey', 'rtspForceTcp: camera.rtspForceTcp',
                      'first.isFrontCameraTest && second.isFrontCameraTest'):
            self.assertIn(token, policy)
        self.assertIn('test(', read('test/map_hud_refresh_policy_test.dart'))
        self.assertIn('test(', read('test/map_camera_source_policy_test.dart'))

    def test_build_is_sequential(self):
        self.assertIn('version: ' + current_release(ROOT), read('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.349.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.349.md').is_file())

if __name__ == '__main__':
    unittest.main()
