from tool.release_version_checks import current_release, version_only, catalog_reference, current_build
"""Prevent shipping the older 341 tree instead of 350 plus RTSP integration."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]

def read(p): return (ROOT/p).read_text('utf-8')

class Restore350Rtsp351(unittest.TestCase):
    def test_preserve_base350_map_trip_and_diagnostics(self):
        for p in (
            'lib/services/retained_mbtiles_tile_provider.dart',
            'lib/services/map_hud_refresh_policy.dart',
            'lib/services/bike_trip_editor_bridge.dart',
            'lib/services/bike_trip_schedule_settings_service.dart',
            'lib/services/map_camera_source_policy.dart',
            'lib/widgets/map_layer_picker_panel.dart',
            'lib/services/map_connectivity_service.dart',
            'android/app/src/main/kotlin/com/vigiaia/app/MonitorBootRecoveryReceiver.kt',
            'tool/test_build294_flutter_analyze_350.py',
            'tool/test_unified_bike_planning_341.py',
            'tool/test_map_background_refactor_349.py',
        ):
            self.assertTrue((ROOT/p).is_file(), p)
        self.assertIn('MapHudRefreshPolicy.evaluate',read('lib/screens/map_monitoring_screen.dart'))
        self.assertIn('RetainedMbTilesTileProvider',read('lib/screens/map_monitoring_screen.dart'))
    def test_rtsp_propagation_in_every_camera_entry(self):
        targets={
            'lib/models/camera_source_selector.dart':'rtspTransport: camera.rtspTransport',
            'lib/screens/monitor_screen_multicamera.dart':'rtspTransport: camera.rtspTransport',
            'lib/services/map_camera_source_policy.dart':'rtspTransport: camera.rtspTransport',
            'lib/controllers/monitor_controller.dart':'transport: config.rtspTransport',
            'lib/controllers/secondary_camera_controller.dart':'transport: sourceConfig.rtspTransport',
            'lib/screens/home_screen.dart':'rtspTransport: rememberedSource.rtspTransport',
        }
        for file, term in targets.items():
            self.assertIn(term,read(file),file)
    def test_media3_does_not_receive_unsupported_transport_parameter(self):
        preview=read('lib/screens/multi_camera_screen.dart')
        match=re.search(r'Media3RtspTestScreen\((.*?)\),',preview,re.S)
        self.assertIsNotNone(match)
        self.assertNotIn('transport:',match.group(1))
        self.assertIn('forceTcp: camera.rtspForceTcp',match.group(1))
        self.assertIn('initialValue: _transport',read('lib/screens/rtsp_camera_editor_dialog.dart'))
    def test_version_and_baseline_policy(self):
        self.assertIn('version: ' + current_release(ROOT),read('pubspec.yaml'))
        self.assertIn('Google Drive',read('AGENTS.md'))
        self.assertIn('versão mais recente',read('AGENTS.md'))
if __name__=='__main__':unittest.main()
