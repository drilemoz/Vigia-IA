"""Structural regression checks for the user-reported cycling UI regression and diagnostics."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(name): return (ROOT / name).read_text(encoding='utf-8')

class RouteAndDiagnostics322(unittest.TestCase):
    def test_bike_speed_and_daily_pace_before_preview(self):
        s=read('lib/screens/map_monitoring_screen.dart')
        region=s.split('Future<void> _previewRouteToSearchResult(',1)[1].split('Future<void> _refreshPreviewPlan',1)[0]
        self.assertLess(region.index('_prepareTravelPreferences(mode)'), region.index('_cyclingRoutes.fetchAlternatives'))
        self.assertIn('if (!await _prepareTravelPreferences(mode)) return;',region)
        self.assertIn("'Velocidade média manual'",s)
        self.assertIn("'Tempo máximo pedalando por dia'",s)
        self.assertIn("'Equilibrar os dias'",s)
    def test_full_navigation_guidance_initially_visible(self):
        s=read('lib/screens/map_monitoring_screen.dart')
        for fn, nextfn in [('_startPreviewNavigation','_navigateToSearchResult'),('_navigateToSearchResult','_focusGooglePoint')]:
            section=s.split('Future<void> '+fn+'(',1)[1].split('Future<void> '+nextfn+'(',1)[0]
            self.assertIn('_navigationPanelMinimized = false;',section)
        self.assertIn('  bool _navigationPanelMinimized = false;',s)
        self.assertNotIn('if (focusLevel == 0 && navigationTarget != null &&',s)
        self.assertNotIn('if (focusLevel == 0 && _previewTarget != null &&',s)
        self.assertIn('MapNavigationMetricCell(',s)
    def test_semantic_map_actions_do_not_capture_coordinates(self):
        s=read('lib/screens/map_monitoring_screen.dart')
        for action in ['selecionar_ponto_no_mapa','planejar_velocidade_bike',
                       'iniciar_navegacao_previa','abrir_opcoes_mapa',
                       'editar_velocidade_previa','encerrar_navegacao']:
            self.assertIn("'"+action+"'",s)
        self.assertNotIn('recordUiAction(\'mapas\', item.title',s)
        self.assertIn("'mapas_menu'",read('lib/screens/map_workspace_shell.dart'))
    def test_android_recorder_samples_in_background_and_bootstrap_matches(self):
        a=read('android/app/src/main/kotlin/com/vigiaia/app/AppDiagnostics.kt')
        self.assertEqual(a,read('tool/android/AppDiagnostics.kt'))
        for expected in ['lastBackgroundSampleAt','30000L','processPssKiB',
                         'retainedSamples", 60','while (samples.size > 60)',
                         'exit.description.orEmpty()','processState', 'fun trimMemory(level: Int)']:
            self.assertIn(expected,a)
        self.assertIn('backgroundSampleIntervalSeconds',a)
        self.assertIn('AppDiagnostics.trimMemory(level)',read('tool/android/VigiaApplication.kt'))
        self.assertIn('sem garantia após suspensão pelo Android',read('lib/services/diagnostic_report_service.dart'))
    def test_rtsp_stale_event_warning(self):
        s=read('lib/services/diagnostic_report_service.dart')
        self.assertIn('isRtspExitClose',s)
        self.assertIn('pode ser registro anterior',s)
    def test_release(self):
        self.assertIn('version: 1.0.331+331',read('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.331.md').is_file())
        self.assertTrue((ROOT/'VALIDATION-1.0.331.md').is_file())

if __name__=='__main__':unittest.main()
