"""Regression guard for fatal Flutter analyzer diagnostics in APK 297."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]

class Build297RtspMedia3Contract341(unittest.TestCase):
    def test_media3_preview_named_parameters_match_call(self):
        source = (ROOT/'lib/screens/media3_rtsp_test_screen.dart').read_text('utf-8')
        multi = (ROOT/'lib/screens/multi_camera_screen.dart').read_text('utf-8')
        constructor = re.search(r'Media3RtspTestScreen\s*\(\s*\{(.*?)\}\s*\)', source, re.S)
        self.assertIsNotNone(constructor)
        supported = set(re.findall(r'(?:required\s+)?this\.(\w+)', constructor.group(1)))
        call = re.search(r'\bMedia3RtspTestScreen\s*\((.*?)\),\s*\n\s*\)', multi, re.S)
        self.assertIsNotNone(call)
        passed = set(re.findall(r'\b(\w+):\s*', call.group(1)))
        self.assertEqual(passed - {'key'}, supported & passed - {'key'})
        self.assertFalse(passed - supported - {'key'},
                         f'Unsupported named parameters: {passed - supported}')
        self.assertEqual({'cameraName','url','forceTcp'}, passed)
        self.assertNotIn('transport:', call.group(1))

    def test_form_field_uses_supported_initial_value(self):
        source = (ROOT/'lib/screens/rtsp_camera_editor_dialog.dart').read_text('utf-8')
        self.assertIn('initialValue: _transport,', source)
        self.assertNotRegex(source, r'DropdownButtonFormField<String>\(\s*value:')

    def test_libvlc_transport_remains_in_primary_pipeline(self):
        multi = (ROOT/'lib/screens/multi_camera_screen.dart').read_text('utf-8')
        self.assertIn('forceTcp: camera.rtspForceTcp', multi)
        monitor = (ROOT/'lib/controllers/monitor_controller.dart').read_text('utf-8')
        secondary = (ROOT/'lib/controllers/secondary_camera_controller.dart').read_text('utf-8')
        for source in (monitor,secondary):
            self.assertIn('transport:', source)

if __name__ == '__main__':
    unittest.main()
