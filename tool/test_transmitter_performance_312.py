"""Contrato de telemetria leve e priorizacao do MP4 no Redmi A3."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def content(path):
    return (ROOT / path).read_text(encoding='utf-8')

class TransmitterPerformance312Tests(unittest.TestCase):
    def test_card_uses_existing_android_telemetry(self):
        screen = content('lib/screens/native_transmitter_screen.dart')
        self.assertIn('readDeviceTelemetry()', screen)
        self.assertIn('_resourceCard()', screen)
        self.assertIn('CPU app:', screen)
        self.assertIn('Memória app:', screen)
        self.assertIn('RAM livre:', screen)
        self.assertIn('appCpuPercent', screen)
        self.assertIn('appMemoryUsedBytes', screen)
        self.assertIn('memoryAvailableBytes', screen)
        self.assertIn('_telemetryTimer = Timer.periodic(const Duration(seconds: 6)', screen)
        self.assertIn('_telemetryTimer?.cancel()', screen)
        tick = screen.split('_telemetryTimer = Timer.periodic', 1)[1].split('    });', 1)[0]
        self.assertNotIn('McrpClient', tick)
        self.assertNotIn('status()', tick)

    def test_recording_priority_and_thermal_guard(self):
        service = content('android/app/src/main/kotlin/com/minhacamera/PhoneCameraBackgroundService.kt')
        policy = content('android/app/src/main/kotlin/com/minhacamera/PhoneRecNetworkPolicy.kt')
        self.assertIn('ecoEnabled && !recording', service)
        self.assertIn('PhoneRecNetworkPolicy.shouldPublish(recording', service)
        self.assertLess(service.index('appendRecording(snapshot,'), service.index('publish(session, rotated,'))
        self.assertIn('viewers > 0', policy)
        self.assertNotIn('200L', policy)
        self.assertIn('2_500L', policy)
        self.assertIn('if (!recording || viewers > 0) return true', policy)
        self.assertIn('heatState == PhoneHeatState.HOT', service)
        for name in ('PhoneCameraBackgroundService.kt', 'PhoneRecNetworkPolicy.kt'):
            self.assertEqual(content('tool/android/native_transmitter/' + name),
                             content('android/app/src/main/kotlin/com/minhacamera/' + name))

    def test_version(self):
        self.assertIn('version: 1.0.318+318', content('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.318.md').is_file())

if __name__ == '__main__':
    unittest.main()
