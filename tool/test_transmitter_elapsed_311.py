"""Regressao para o salto 10->13s nos cronometros do transmissor A3."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeElapsed311Contracts(unittest.TestCase):
    def test_relogio_monotonico_e_desenho_a_um_hz(self):
        screen = (ROOT / 'lib/screens/native_transmitter_screen.dart').read_text()
        counter = (ROOT / 'lib/services/native_elapsed_counter.dart').read_text()
        self.assertIn('Stopwatch()..start()', screen)
        self.assertIn('_displayTimer = Timer.periodic(const Duration(seconds: 1)', screen)
        self.assertIn('_timer = Timer.periodic(const Duration(seconds: 3)', screen)
        self.assertIn('_transmitElapsed.secondsAt(now)', screen)
        self.assertIn('_recordElapsed.secondsAt(now)', screen)
        self.assertIn('statusSampledAt = _elapsedClock.elapsed', screen)
        self.assertIn('recordingSampledAt = _elapsedClock.elapsed', screen)
        self.assertIn('_displayTimer?.cancel()', screen)
        self.assertIn('elapsed.inSeconds', counter)
        self.assertIn('if (!active)', counter)

    def test_sem_aumento_de_consultas_a_camera(self):
        source = (ROOT / 'lib/screens/native_transmitter_screen.dart').read_text()
        tick = source.split('_displayTimer = Timer.periodic', 1)[1].split('  });', 1)[0]
        self.assertNotIn('_refresh()', tick)
        self.assertNotIn('McrpClient(', tick)
        self.assertNotIn('NativeCameraTransmitterService.status()', tick)

    def test_versao_publica_e_testes_de_clock(self):
        self.assertIn('version: 1.0.318+318', (ROOT/'pubspec.yaml').read_text())
        self.assertTrue((ROOT / 'RELEASE-1.0.318.md').is_file())
        tests = (ROOT / 'test/native_elapsed_counter_test.dart').read_text()
        self.assertIn('11);', tests)
        self.assertIn('12);', tests)
        self.assertIn('13);', tests)
        self.assertIn('reinicio', tests)


if __name__ == '__main__':
    unittest.main()
