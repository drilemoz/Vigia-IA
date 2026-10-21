"""Contratos da trilha de UI 319: não substituem Flutter/Android compilados."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text('utf8')


class UiDiagnostics319(unittest.TestCase):
    def test_capture_in_material_app(self):
        app = source('lib/app/app.dart')
        self.assertIn('navigatorObservers: [DiagnosticRouteObserver.instance]', app)
        self.assertIn('builder: (context, child) => DiagnosticUiInteractionCapture(', app)
        observer = source('lib/services/diagnostic_route_observer.dart')
        for method in ['didPush(', 'didPop(', 'didRemove(', 'didReplace(']:
            self.assertIn(method, observer)
        self.assertNotIn('route.settings.name', observer)

    def test_taps_ignore_passwords_editing_and_swipes(self):
        capture = source('lib/widgets/diagnostic_ui_interaction_capture.dart')
        for marker in ('PointerDeviceKind.touch', 'viewInsetsOf(context)',
                       'EditableText', 'onPointerCancel:', 'distance > 24',
                       'Duration(milliseconds: 700)', 'size.width * 3',
                       'size.height * 3'):
            self.assertIn(marker, capture)
        self.assertNotIn('TextEditingController', capture)
        self.assertNotIn('event.position.toString()', capture)

    def test_navigation_and_camera_actions(self):
        nav = source('lib/widgets/main_navigation_bar.dart')
        self.assertEqual(nav.count('.setUiSection(_mainDestinations[index].label)'), 2)
        cam = source('lib/screens/multi_camera_screen_components.dart')
        self.assertIn("recordUiAction('opcoes_camera', value)", cam)
        self.assertIn("'monitorar_${camera.type.name}'", cam)
        root = source('lib/screens/multi_camera_screen.dart')
        self.assertIn("'parear_qr'", root)
        self.assertIn("'adicionar_${type.name}'", root)
        self.assertIn("'escanear_rede'", source('lib/screens/multi_camera_screen_lan_discovery.dart'))
        media3 = source('lib/screens/media3_rtsp_test_screen.dart')
        for marker in ('abrir_previa', 'view_criada', 'tentar_novamente', 'media3_estado'):
            self.assertIn(marker, media3)
        self.assertIn('permitted.contains(phase)', media3)

    def test_critical_events_persist_to_disk_and_recover(self):
        native = source('android/app/src/main/kotlin/com/vigiaia/app/AppDiagnostics.kt')
        template = source('tool/android/AppDiagnostics.kt')
        self.assertEqual(native, template)
        self.assertIn('urgent: Boolean = false', native)
        self.assertIn('isUnhandled || urgent ||', native)
        self.assertIn('while (events.size > 120)', native)
        self.assertIn('checkpointUiAction(detail: String)', native)
        self.assertIn('uiPrefs.edit().putString("last"', native)
        self.assertIn('.commit()', native)
        self.assertIn('lastUiActionBeforeExit', native)
        self.assertIn('lastUiAction', native)
        main = source('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertEqual(main, source('tool/android/MainActivity.kt'))
        self.assertIn('AppDiagnostics.checkpointUiAction(', main)
        self.assertIn('call.argument<Boolean>("urgent") == true', main)

    def test_export_and_privacy(self):
        automatic = source('lib/services/automatic_diagnostics_service.dart')
        self.assertIn("'urgent': true", automatic)
        self.assertIn('Último clique anterior à saída:', automatic)
        report = source('lib/services/diagnostic_report_service.dart')
        self.assertIn('INTERAÇÕES DE INTERFACE (ANTES DO ENCERRAMENTO)', report)
        self.assertIn('ÚLTIMA AÇÃO ANTES DA SAÍDA:', report)
        self.assertIn('lastUiAction', report)
        self.assertIn('DiagnosticRedactor.text(', report)
        self.assertIn('Regiões de toque são aproximadas.', report)
        self.assertNotIn('recordUiAction(', source('lib/utils/diagnostic_redactor.dart'))

    def test_version_and_notes(self):
        self.assertIn('version: 1.0.321+321', source('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.321.md').is_file())
        self.assertTrue((ROOT / 'VALIDATION-1.0.321.md').is_file())


if __name__ == '__main__':
    unittest.main()
