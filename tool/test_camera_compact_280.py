"""Guarda de layout da Central de Câmeras 1.0.280 (sem depender de Flutter SDK)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def source(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


class CameraCompact280(unittest.TestCase):
    def test_info_is_an_action_next_to_metrics_not_full_banner(self):
        ui = source('lib/screens/multi_camera_screen_components.dart')
        header = ui.split('class _SourceAction', 1)[0]
        self.assertIn('IconButton(', header)
        self.assertIn('Icons.help_outline_rounded', header)
        self.assertIn("tooltip: 'Sobre as câmeras e a contagem'", header)
        self.assertIn('showDialog<void>(', header)
        self.assertIn('Cada câmera é independente.', header)
        self.assertIn("label: '$total câmeras'", header)
        self.assertIn("label: '$online online'", header)
        self.assertNotIn('GridView.count(', header)

    def test_four_add_source_actions_in_one_row_without_changing_callbacks(self):
        ui = source('lib/screens/multi_camera_screen_components.dart')
        header = ui.split('class _SourceAction', 1)[0]
        segment = header.split("'Adicionar fonte'", 1)[1]
        self.assertIn('Row(', segment)
        self.assertEqual(segment.count('child: _SourceAction('), 4)
        for label, callback in [('QR', 'onScanPhone'), ('Celular', 'onAddPhone'),
                                ('RTSP', 'onAddRtsp'), ('ESP32', 'onManageEsp32')]:
            self.assertIn(f"label: '{label}'", segment)
            self.assertIn(f'onPressed: {callback}', segment)
        self.assertNotIn('GridView.count(', segment)
        self.assertIn('minimumSize: const Size(0, 58)', ui)

    def test_local_camera_shows_event_without_redundant_device_detail(self):
        cameras = source('lib/screens/multi_camera_screen.dart')
        ui = source('lib/screens/multi_camera_screen_components.dart')
        details = source('lib/screens/multi_camera_screen_details.dart')
        self.assertIn("name: 'Câmera celular'", cameras)
        self.assertNotIn('Dispositivo: este celular', details)
        self.assertIn('if (camera.type != CameraEndpointType.local)', ui)
        self.assertIn("'Último evento: nenhum registrado'", ui)
        self.assertIn('lastEvent!.displayLabel', ui)

    def test_mobile_cards_are_content_sized_other_widths_preserve_grid(self):
        cameras = source('lib/screens/multi_camera_screen.dart')
        self.assertIn('sliver: columns == 1', cameras)
        self.assertIn('SliverList(', cameras)
        self.assertIn('SliverGrid(', cameras)
        self.assertIn('childCount: cameras.length', cameras)
        self.assertIn('mainAxisExtent: 220', cameras)
        self.assertIn('onMcrpControls: MinhaCameraLiveUrl.isValid', cameras)
        self.assertIn('onDelete: camera.id', cameras)

if __name__ == '__main__':
    unittest.main()
