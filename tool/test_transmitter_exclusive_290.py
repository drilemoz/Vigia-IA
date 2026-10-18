"""Contratos de isolamento do Vigia IA 1.0.290; não substituem teste em Android."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def src(path):
    return (ROOT / path).read_text(encoding='utf-8')

class TransmitterExclusive290(unittest.TestCase):
    def test_saved_mode_restores_android_guard(self):
        s=src('lib/services/app_launch_mode_service.dart')
        self.assertIn('await TransmitterExclusivePolicy.apply(_mode == AppLaunchMode.transmission)',s)
        self.assertIn('await TransmitterExclusivePolicy.apply(mode == AppLaunchMode.transmission)',s)
        self.assertIn('suspendForTransmitter()',s)

    def test_no_global_services_on_transmitter_startup(self):
        s=src('lib/app/app.dart')
        self.assertIn('completed && launchMode != AppLaunchMode.transmission',s)
        self.assertIn('if (TransmitterExclusivePolicy.enabled',s)
        self.assertIn('widget.transmitterExclusive',s)

    def test_no_cross_module_navigation(self):
        s=src('lib/screens/native_transmitter_screen.dart')
        self.assertIn('PopScope(',s)
        self.assertIn('canPop: false',s)
        self.assertNotIn('navigateToMainDestination',s)
        self.assertIn('await NativeCameraTransmitterService.stop()',s)
        self.assertIn('await AppLaunchModeService.instance.save(AppLaunchMode.normal)',s)

    def test_guard_native_monitor_and_radio(self):
        s=src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertIn('TransmitterExclusiveMode.enabled(this)',s)
        self.assertIn('vigiaia/transmitter_exclusive',s)
        for name in ('MonitoringForegroundService.kt','RadioPlaybackService.kt'):
            self.assertIn('TransmitterExclusiveMode.enabled(this)',src('android/app/src/main/kotlin/com/vigiaia/app/'+name))

    def test_stop_exits_when_remote_capture_paused(self):
        source=src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertIn('service.streamUrl != null',source)
        self.assertIn('ACTION_STOP',source)

    def test_recovery_and_audio_cannot_restart(self):
        receiver=src('android/app/src/main/kotlin/com/vigiaia/app/MonitorRecoveryReceiver.kt')
        self.assertIn('TransmitterExclusiveMode.enabled(context)',receiver)
        channel=src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertIn('call.method != "status" && call.method != "stop"',channel)
        self.assertIn('stopService(Intent(context, RadioPlaybackService::class.java))',
                      src('android/app/src/main/kotlin/com/vigiaia/app/TransmitterExclusiveMode.kt'))

    def test_video_viewers_not_http_peers(self):
        s=src('android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt')
        self.assertIn('private val videoViewers = AtomicInteger()',s)
        self.assertIn('fun activeVideoViewers(): Int',s)
        self.assertEqual(s.count('videoViewers.incrementAndGet()'),2)
        self.assertEqual(s.count('videoViewers.decrementAndGet()'),2)

    def test_idle_limit_excludes_recording(self):
        s=src('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt')
        self.assertIn('session.activeVideoViewers() == 0 && !recording',s)
        self.assertIn('val interval = if (idle) 2_500L',s)
        self.assertIn('PowerManager.THERMAL_STATUS_EMERGENCY',s)
        self.assertIn('heatState == PhoneHeatState.WARM',s)
        self.assertIn('getBoolean("eco_enabled", true)',s)

    def test_thermal_status_exposed_without_exposing_keys(self):
        server=src('android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt')
        self.assertIn('X-Thermal-Status:',server)
        self.assertIn('thermalStatus = { thermalStatus }',src('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt'))
        self.assertIn("'x-thermal-status'",src('lib/services/mcrp_client.dart'))
        self.assertIn('thermalLabels[thermal]',src('lib/screens/native_transmitter_screen.dart'))

    def test_bootstrap_is_authoritative(self):
        b=src('tool/bootstrap_android.sh')
        self.assertIn('TransmitterExclusiveMode.kt',b)
        for name in ('MainActivity.kt','MonitoringForegroundService.kt','RadioPlaybackService.kt','TransmitterExclusiveMode.kt','MonitorRecoveryReceiver.kt'):
            a=src('android/app/src/main/kotlin/com/vigiaia/app/'+name)
            self.assertEqual(a,src('tool/android/'+name))
        for name in ('PhoneCameraServer.kt','PhoneCameraBackgroundService.kt','PhoneEcoPolicy.kt'):
            a=src('android/app/src/main/kotlin/com/minhacamera/'+name)
            self.assertEqual(a,src('tool/android/native_transmitter/'+name))

if __name__=='__main__':unittest.main()
