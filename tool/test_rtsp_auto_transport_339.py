from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
read=lambda x:(ROOT/x).read_text()
class RtspAutoTransport339(unittest.TestCase):
 def test_mode_persists_and_legacy_defaults(self):
  for f in ('lib/models/camera_endpoint.dart','lib/models/video_source_config.dart'):
   s=read(f)
   for item in ("this.rtspTransport = 'auto'", "'rtspTransport': rtspTransport", "json['rtspTransport']", "json['rtspForceTcp']"):
    self.assertIn(item,s)
 def test_editor_and_multi_camera(self):
  self.assertIn("DropdownMenuItem(value: 'auto'",read('lib/screens/rtsp_camera_editor_dialog.dart'))
  for f in ('lib/controllers/monitor_controller.dart','lib/controllers/secondary_camera_controller.dart','lib/screens/multi_camera_screen.dart'):
   self.assertIn('transport:',read(f))
 def test_real_frame_confirmation_and_fallback(self):
  s=read('lib/sources/rtsp_camera_source.dart')
  for item in ("_loadPreferredTransport() ?? 'udp'", "_switchTransport('first_frame_timeout')", "_switchTransport('player_error')", "unawaited(_rememberTransport())", "':rtsp-tcp'", 'await controller.setMedia(_mediaSource, autoPlay: true)'):
   self.assertIn(item,s)
  self.assertIn('sha256.convert(utf8.encode(url))',s)
  self.assertIn('if (rawH264 || transport != \'auto\') return;',s)
 def test_version(self):
  self.assertIn('version: 1.0.339+339',read('pubspec.yaml'))
if __name__=='__main__':unittest.main()
