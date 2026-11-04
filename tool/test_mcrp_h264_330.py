from pathlib import Path
import unittest

R = Path(__file__).resolve().parents[1]

def source(path):
    return (R / path).read_text('utf-8')

class TestMcrpH264Integration(unittest.TestCase):
    def test_private_h264_url_derived_from_validated_live(self):
        s = source('lib/services/minha_camera_live_url.dart')
        self.assertIn('static Uri? h264FromLive', s)
        self.assertIn('final live = parse(liveUrl);', s)
        self.assertIn("'/h264/${live.pathSegments.last}'", s)
        self.assertIn('static bool isValidH264', s)
    def test_mcrp_auto_select_and_no_two_network_decoder_branches(self):
        s = source('lib/sources/minha_camera_mjpeg_source.dart')
        self.assertIn("headers['x-stream-codec']", s)
        self.assertIn('HttpStatus.conflict', s)
        self.assertIn('await _useH264(generation);', s)
        self.assertIn('await old.dispose()', s)
        self.assertIn('rawH264: true', s)
        self.assertIn('if (_disposed || generation != _generation || _codec != \'mjpeg\') return;', s)
    def test_libvlc_http_demux_with_bounded_recovery(self):
        s = source('lib/sources/rtsp_camera_source.dart')
        self.assertIn("if (rawH264) ':demux=h264'", s)
        self.assertIn('MinhaCameraLiveUrl.isValidH264(url)', s)
        self.assertIn('RtspFrameWatchdogPolicy', s)
        self.assertIn('possible_frame_stall', s)
        self.assertIn('RtspRecoveryPolicy()', s)
        self.assertIn('takeSnapshot(width: 640)', s)
    def test_ia_enabled_for_both_codecs_in_mcrp(self):
        s = source('lib/screens/mcrp_camera_screen.dart')
        self.assertIn('MJPEG ou H.264', s)
        self.assertIn("ValueKey('remote_$_streamRevision')", s)
        self.assertIn('analysisEnabled: _analyze', s)
        self.assertNotIn('A IA local exige MJPEG', s)
    def test_build_and_release(self):
        self.assertIn('version: 1.0.347+347', source('pubspec.yaml'))
        self.assertTrue((R / 'RELEASE-1.0.347.md').exists())

if __name__ == '__main__':
    unittest.main()
