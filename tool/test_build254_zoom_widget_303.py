"""Regressao do Flutter Test do build 254: modal zoom compacto vs. seletores.

A verificacao nao substitui flutter test em CI; apenas detecta texto desatualizado
no contrato dos testes do controle remoto.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Build254ZoomWidget303(unittest.TestCase):
    def test_compact_zoom_dialog_contract(self):
        widget = (ROOT / 'lib/widgets/mcrp_remote_controls.dart').read_text('utf-8')
        test = (ROOT / 'test/mcrp_remote_controls_test.dart').read_text('utf-8')
        self.assertIn("const Expanded(child: Text('Zoom',", widget)
        for tooltip in ('Fechar', 'Aumentar zoom', 'Diminuir zoom', 'Zoom original (1×)'):
            self.assertIn("tooltip: '" + tooltip + "'", widget)
        self.assertIn("key: const Key('mcrp_zoom_dialog')", widget)
        self.assertIn("find.byKey(const Key('mcrp_zoom_dialog'))", test)
        self.assertIn("find.descendant(of: zoomDialog, matching: find.text('Zoom'))", test)
        self.assertNotIn("expect(find.text('Zoom'), findsOneWidget)", test)
        self.assertIn("tester.tap(find.byTooltip('Zoom original (1×)'))", test)
        self.assertIn("tester.tap(find.byTooltip('Fechar'))", test)
        self.assertNotIn("find.text('Tamanho original (1×)')", test)
        self.assertNotIn("find.text('Zoom da câmera'), findsOneWidget", test)

    def test_commands_are_still_asserted(self):
        test = (ROOT / 'test/mcrp_remote_controls_test.dart').read_text('utf-8')
        for command in ('record/start', 'zoom/50', 'zoom/0', 'quality/480', 'fps/10', 'torch/30'):
            self.assertIn("'" + command + "'", test)


if __name__ == '__main__':
    unittest.main()
