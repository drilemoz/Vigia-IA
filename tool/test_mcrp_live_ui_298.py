"""Valida ligação estática entre serviço nativo e HUD, sem fingir teste Android."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
read=lambda name:(R/name).read_text(encoding='utf8')
class McrpLiveUi298(unittest.TestCase):
    def test_server_is_authority_of_state_and_elapsed(self):
        server=read('android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt')
        service=read('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt')
        for key in ('X-Recording-Seconds:', 'X-Transmission-Seconds:', 'X-Transmitting:'):
            self.assertIn(key,server)
        self.assertIn('SystemClock.elapsedRealtime() - recordingStartMs',service)
        self.assertIn('SystemClock.elapsedRealtime() - transmissionStartedMs',service)
    def test_no_stale_frame_or_false_live_state(self):
        stage=read('lib/screens/monitor_screen_multicamera.dart')
        remote=read('lib/widgets/mcrp_remote_controls.dart')
        self.assertIn('if (paused || unavailable || unknown || (transmitting && !videoReady))',stage)
        self.assertIn('TRANSMISSÃO PARADA',stage)
        self.assertIn('CONEXÃO PERDIDA',stage)
        self.assertIn("'x-link-unavailable': '1'",remote)
        self.assertIn('McrpLiveStatusCache.setStatus(widget.liveUrl, status)',remote)
    def test_status_below_video_and_independent_rec(self):
        support=read('lib/screens/monitor_screen_mcrp_support.dart')
        portrait=read('lib/screens/monitor_screen_portrait.dart')
        tx=read('lib/screens/native_transmitter_screen.dart')
        self.assertIn('McrpLiveStatusCache.duration(recordingTime)',support)
        self.assertIn('McrpLiveStatusCache.duration(transmissionTime)',support)
        self.assertIn('_buildMcrpRecordingStrip(context)',portrait)
        self.assertIn('if (url != null) ...[',tx)
