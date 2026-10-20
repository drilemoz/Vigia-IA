"""Executa a lógica Kotlin de produção e verifica sua ligação ao serviço Android."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / 'android/app/src/main/kotlin/com/minhacamera'


class Transmitter313Tests(unittest.TestCase):
    def test_recording_is_scheduled_outside_network_worker(self):
        source = (NATIVE / 'PhoneCameraBackgroundService.kt').read_text()
        callback = source.split('opened.setPreviewCallbackWithBuffer { bytes, source ->', 1)[1].split('repeat(3)', 1)[0]
        self.assertLess(callback.index('appendRecording(snapshot,'), callback.index('encodeWorker.execute'))
        self.assertIn('val takeRecord = recordDue && recordingBusy.compareAndSet', callback)
        self.assertIn('val takeStream = streamPacer.accept', callback)
        self.assertIn('generation == recordingGeneration', source)
        recorder = (NATIVE / 'PhoneMp4Recorder.kt').read_text()
        self.assertIn('setOrientationHint(orientationDegrees)', recorder)
        self.assertNotIn('Nv21Frames.rotated', recorder)
        self.assertIn('candidate.isHardwareAccelerated', recorder)
        self.assertNotIn('PhoneYuv420.convert', recorder)
        server = (NATIVE / 'PhoneCameraServer.kt').read_text()
        self.assertNotIn('latestAvc', server)
        self.assertIn('avcQueue.read(cursor,', server)

    def test_kotlin_behavior(self):
        compiler, java = shutil.which('kotlinc'), shutil.which('java')
        if not compiler or not java:
            self.skipTest('Kotlin JVM indisponível; executar este teste com kotlinc no PATH')
        sources = ['PhoneFramePacer.kt', 'PhoneYuv420.kt', 'PhoneAvcQueue.kt',
                   'PhoneRecNetworkPolicy.kt', 'PhoneEcoPolicy.kt']
        with tempfile.TemporaryDirectory(prefix='transmitter313-') as directory:
            jar = Path(directory) / 'test.jar'
            subprocess.run([compiler, *[str(NATIVE / name) for name in sources],
                            str(ROOT / 'tool/kotlin/Transmitter313Test.kt'),
                            '-include-runtime', '-d', str(jar)], check=True, timeout=90)
            result = subprocess.run([java, '-jar', str(jar)], check=True, capture_output=True,
                                    text=True, timeout=20)
            self.assertIn('PASS:', result.stdout)
            print(result.stdout.strip())


if __name__ == '__main__':
    unittest.main()
