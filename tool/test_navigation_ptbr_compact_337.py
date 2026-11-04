"""Regressões da navegação pt-BR, painel compacto e proteção contra GPS antigo."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(path):
    return (ROOT / path).read_text(encoding='utf-8')


class Navigation337(unittest.TestCase):
    def test_languages_in_providers(self):
        text = src('lib/services/map_cycling_route_service.dart')
        self.assertIn("'language': 'pt-BR'", text)
        self.assertIn("'language': 'pt'", text)
        self.assertNotIn("'language': 'pt-PT'", text)

    def test_localizer_used_for_ors_and_valhalla(self):
        text = src('lib/services/map_cycling_route_service.dart')
        self.assertIn("MapNavigationInstructionPtBr.localize(", text)
        self.assertIn('instruction: MapNavigationInstructionPtBr.localize(instruction)', text)
        self.assertTrue((ROOT / 'test/map_navigation_instruction_ptbr_test.dart').is_file())

    def test_translation_is_shared_by_tts_and_ui(self):
        text = src('lib/services/map_navigation_guidance.dart')
        self.assertIn('currentInstruction: MapNavigationInstructionPtBr.localize(current.instruction)', text)
        self.assertIn('MapNavigationInstructionPtBr.localize(next.instruction)', text)
        voice = src('lib/services/map_navigation_voice_policy.dart')
        self.assertIn('progress.nextInstruction', voice)
        self.assertIn('formatDistanceForSpeech(distance)', voice)

    def test_compact_is_default_in_new_routes(self):
        text = src('lib/screens/map_monitoring_screen.dart')
        self.assertIn('bool _navigationPanelMinimized = true;', text)
        for before, after in (('_startPreviewNavigation', '_navigateToSearchResult'),
                              ('_navigateToSearchResult', '_focusGooglePoint')):
            section = text.split('Future<void> ' + before + '(', 1)[1].split('Future<void> ' + after + '(', 1)[0]
            self.assertIn('_navigationPanelMinimized = true;', section)
        self.assertIn('Expandir detalhes da navegação', text)

    def test_gps_is_required_for_maneuvers(self):
        text = src('lib/screens/map_monitoring_screen.dart')
        self.assertIn('if (!MapTelemetryPolicy.isFresh(current) || route == null', text)
        self.assertIn('_navigationProgress = null; // Nunca manter manobra antiga', text)
        self.assertIn('positionFresh: _routeState.availability ==', text)
        self.assertIn('Aguardando localização GPS', text)
        self.assertIn('Orientações pausadas até receber nova posição.', text)
        self.assertIn('if (positionFresh) ClipRRect', text)

    def test_route_has_explicit_color_and_thinner_lines(self):
        text = src('lib/screens/map_monitoring_screen.dart')
        self.assertIn('color: palette.routeColor', text)
        self.assertIn('color: palette.routeCasingColor.withValues(alpha: 0.72)', text)
        self.assertIn("polylineId: const gmaps.PolylineId('cycling-route'),\n        points: points, width: 4,", text)
        self.assertIn('strokeWidth: 7,\n                            color: mapPalette.routeCasingColor', text)

    def test_hide_empty_nearby_cards_and_duplicate_mode(self):
        text = src('lib/screens/map_monitoring_screen.dart')
        self.assertIn('if (water != null || food != null || rest != null || stop != null)', text)
        self.assertIn("widget.workspaceModeLabel?.toLowerCase() == 'navegar'", text)
        self.assertIn('positionFresh ? \'restantes\' : \'planejados\'', text)

    def test_version_and_release(self):
        self.assertIn('version: 1.0.350+350', src('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.348.md').is_file())
        self.assertTrue((ROOT / 'VALIDATION-1.0.348.md').is_file())


if __name__ == '__main__':
    unittest.main()
