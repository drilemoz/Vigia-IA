"""Regressao do gate MCRP apos suporte a H.264 e IA local na 1.0.331."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding='utf8')

class TestMcrpCodecGate331(unittest.TestCase):
    def test_h264_is_never_fed_to_mjpeg_parser(self):
        source = read('lib/sources/minha_camera_mjpeg_source.dart')
        self.assertIn("if (_disposed || generation != _generation || _codec != 'mjpeg') return;", source)
        self.assertIn('for (final jpeg in parser.add(chunk)) {', source)
        self.assertIn('if (response.statusCode == HttpStatus.conflict) {', source)
        self.assertIn('await _useH264(generation);', source)

    def test_h264_uses_vlc_frames_for_ai(self):
        source = read('lib/sources/minha_camera_mjpeg_source.dart')
        vlc = read('lib/sources/rtsp_camera_source.dart')
        self.assertIn('rawH264: true', source)
        self.assertIn('emitFrames: emitFrames', source)
        self.assertIn('_h264Frames = source.frames.listen((frame)', source)
        self.assertIn("if (rawH264) ':demux=h264'", vlc)
        self.assertIn('takeSnapshot(width: 640)', vlc)

    def test_toggle_remains_available_for_both_codecs(self):
        ui = read('lib/screens/mcrp_camera_screen.dart')
        self.assertIn('MJPEG ou H.264', ui)
        self.assertIn('analysisEnabled: _analyze', ui)
        self.assertNotIn("onChanged: codec == 'h264' ? null", ui)

if __name__ == '__main__':
    unittest.main()
