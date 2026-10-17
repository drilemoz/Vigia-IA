"""Regressão do limitador de câmera local: intervalo configurado prevalece."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(name): return (ROOT / name).read_text(encoding='utf-8')

class LocalCameraFps268(unittest.TestCase):
    def test_900ms_cap_removed_and_250ms_safety_kept(self):
        src = read('lib/controllers/monitor_controller_ai_support.dart')
        self.assertNotIn('requestedInterval < const Duration(milliseconds: 900)', src)
        self.assertIn('requestedInterval < const Duration(milliseconds: 250)', src)
        self.assertIn('return requestedInterval;', src)

    def test_configured_target_and_bike_policy(self):
        config = read('lib/models/video_source_config.dart')
        bike = read('lib/models/bike_mode_config.dart')
        controller = read('lib/controllers/monitor_controller.dart')
        self.assertIn('this.analysisInterval = const Duration(milliseconds: 400)', config)
        self.assertIn('BikePowerProfile.economy => 650', bike)
        self.assertIn('BikePowerProfile.extremeEconomy => 1000', bike)
        self.assertIn('monitor._bikeConfig.effectiveAnalysisInterval(', read('lib/controllers/monitor_controller_ai_support.dart'))
        self.assertIn('_effectiveMonitorAnalysisInterval(this, config)', controller)

    def test_backpressure_protects_cpu_and_preview(self):
        shared = read('lib/services/shared_local_camera_service.dart')
        monitor = read('lib/controllers/monitor_controller.dart')
        self.assertIn('if (_converting || _consumers.isEmpty) return;', shared)
        self.assertIn('CameraPreview(active, key: ObjectKey(active))', shared)
        self.assertIn('if (_processing || !_baseReady || !_detector.isReady)', monitor)
        self.assertIn('clamp(250, 5000)', shared)

    def test_slider_allows_250ms_and_diagnostic_shows_effective_interval(self):
        advanced = read('lib/screens/advanced_settings_screen.dart')
        diagnostic = read('lib/widgets/session_status_panel.dart')
        self.assertIn('min: 250,', advanced)
        self.assertIn('divisions: 35,', advanced)
        self.assertIn('intervalo ${data.expectedFrameIntervalMs} ms', diagnostic)
        self.assertIn('data.expectedFrameIntervalMs', diagnostic)

    def test_unrelated_remote_video_keeps_its_own_cadence(self):
        support = read('lib/controllers/monitor_controller_ai_support.dart')
        self.assertIn('config.type == VideoSourceType.localCamera', support)
        self.assertIn('return requestedInterval;', support)

if __name__ == '__main__': unittest.main()
