"""APK 289: prévia Bike deve testar o editor unificado, não carregamento legado.

Checagem de contrato, não substitui o teste Flutter de widget real.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / 'test/map_route_preview_card_test.dart'
WIDGET = ROOT / 'lib/widgets/map_route_preview_card.dart'
MAP = ROOT / 'lib/screens/map_monitoring_screen.dart'

class PreviewBikePlan344Test(unittest.TestCase):
    def test_preview_text_matches_widget(self):
        test = TEST.read_text('utf-8')
        widget = WIDGET.read_text('utf-8')
        self.assertIn("label: Text(plan == null ? 'Planejar viagem'", widget)
        self.assertIn("expect(find.text('Planejar viagem'), findsOneWidget)", test)
        self.assertNotIn("expect(find.text('Carregando plano'), findsOneWidget)", test)
        self.assertIn("expect(find.text('Plano 2d'), findsOneWidget)", test)

    def test_editor_is_clickable_without_precomputed_plan(self):
        test = TEST.read_text('utf-8')
        widget = WIDGET.read_text('utf-8')
        screen = MAP.read_text('utf-8')
        self.assertIn("sem plano calculado ainda abre o editor unificado", test)
        self.assertIn('expect(button.onPressed, isNotNull)', test)
        self.assertIn("expect(actions, ['plano'])", test)
        self.assertIn('onPressed: onPlan', widget)
        self.assertIn('onPlan: _previewRoutes.isEmpty || _previewLoading', screen)
        self.assertIn('onPlan: mode == MapTravelMode.bicycle && !loading &&', test)

    def test_version_incremented(self):
        self.assertIn('version: 1.0.353+353', (ROOT/'pubspec.yaml').read_text('utf-8'))
        self.assertTrue((ROOT/'RELEASE-1.0.348.md').exists())
        self.assertTrue((ROOT/'VALIDATION-1.0.348.md').exists())

if __name__ == '__main__':
    unittest.main()
