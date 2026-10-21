"""Impede que testes Dart antigos quebrem o workflow após redesign de UI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return (ROOT / name).read_text(encoding='utf-8')


class Build248WidgetContracts(unittest.TestCase):
    def test_main_navigation_and_widget_assertions_match(self):
        source = read('lib/widgets/main_navigation_bar.dart')
        test = read('test/main_navigation_bar_test.dart')
        self.assertEqual(source.count('label: \'Início\''), 1)
        for name in ('Início', 'Histórico', 'Ao vivo', 'Câmeras', 'Galeria', 'Mapas'):
            self.assertIn(f"label: '{name}'", source)
            self.assertIn(f"find.text('{name}')", test)
        self.assertNotIn("label: 'Ajustes'", source)
        self.assertIn('findsNWidgets(6)', test)
        self.assertIn("expect(find.text('Ajustes'), findsNothing)", test)

    def test_mcrp_modal_commands_checked_not_merely_renamed(self):
        source = read('lib/widgets/mcrp_remote_controls.dart')
        test = read('test/mcrp_remote_controls_test.dart')
        for expected in ("'Vídeo'", 'Resolução e FPS', 'Lanterna do transmissor',
                         'quality/480', 'fps/10', 'torch/30'):
            self.assertIn(expected, source + test)
        self.assertIn("tester.tap(find.text('Vídeo'))", test)
        self.assertIn("tester.tap(find.text('480p'))", test)
        self.assertIn("tester.tap(find.text('10 FPS'))", test)
        self.assertIn("tester.tap(find.text('Ligar por 30 segundos'))", test)
        self.assertNotIn("tester.tap(find.text('Resolução'))", test)

    def test_version(self):
        self.assertIn('version: 1.0.319+319', read('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.319.md').is_file())


if __name__ == '__main__':
    unittest.main()
