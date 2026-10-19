"""Guarda de regressao: nao consultar titulos identicos em toda a arvore de widgets."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
class Build255ZoomScope304(unittest.TestCase):
    def test_zoom_dialog_has_stable_scope(self):
        widget = (ROOT/'lib/widgets/mcrp_remote_controls.dart').read_text('utf8')
        test = (ROOT/'test/mcrp_remote_controls_test.dart').read_text('utf8')
        self.assertIn("key: const Key('mcrp_zoom_dialog')", widget)
        self.assertIn("final zoomDialog = find.byKey(const Key('mcrp_zoom_dialog'));", test)
        self.assertIn("find.descendant(of: zoomDialog, matching: find.text('Zoom'))", test)
        self.assertIn("expect(zoomDialog, findsNothing)", test)
        self.assertNotIn("expect(find.text('Zoom'), findsOneWidget)", test)
    def test_remote_commands_not_removed(self):
        test = (ROOT/'test/mcrp_remote_controls_test.dart').read_text('utf8')
        for cmd in ('record/start', 'zoom/50', 'zoom/0', 'quality/480', 'fps/10', 'torch/30'):
            self.assertIn("'"+cmd+"'", test)
if __name__ == '__main__': unittest.main()
