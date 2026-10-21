"""Build 266: impede URL opcional em Media3RtspTestScreen.

Teste estrutural, não substitui flutter analyze.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Build266Media3NullSafety318(unittest.TestCase):
    def test_url_optional_in_registry_model(self):
        model = (ROOT / 'lib/models/camera_endpoint.dart').read_text('utf8')
        self.assertIn('final String? address;', model)

    def test_preview_requires_present_nonempty_rtsp_address(self):
        source = (ROOT / 'lib/screens/multi_camera_screen.dart').read_text('utf8')
        self.assertIn('final rtspTestUrl = camera.address;', source)
        self.assertIn('camera.type == CameraEndpointType.rtsp &&', source)
        self.assertIn('rtspTestUrl != null &&', source)
        self.assertIn('rtspTestUrl.trim().isNotEmpty', source)
        self.assertIn('url: rtspTestUrl,', source)
        self.assertNotIn('url: camera.address,', source)
        self.assertNotIn('url: camera.address!', source)

    def test_media3_screen_requires_valid_string(self):
        source = (ROOT / 'lib/screens/media3_rtsp_test_screen.dart').read_text('utf8')
        self.assertIn('final String url;', source)
        self.assertIn("viewType: 'vigiaia/media3_rtsp'", source)

    def test_version_increment(self):
        self.assertIn('version: 1.0.320+320', (ROOT / 'pubspec.yaml').read_text('utf8'))
        self.assertTrue((ROOT / 'RELEASE-1.0.320.md').is_file())

if __name__ == '__main__':
    unittest.main()
