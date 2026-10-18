"""Regras do modo remoto compacto e início leve da IA na versão 293."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
read=lambda file:(ROOT/file).read_text(encoding='utf8')

class CompactRemote293(unittest.TestCase):
    def test_zoom_and_resolution_keep_authenticated_commands(self):
        ui=read('lib/widgets/mcrp_remote_controls.dart')
        self.assertIn("'Zoom',",ui)
        self.assertIn("'Resolução',",ui)
        self.assertIn('_openZoomDialog(context)',ui)
        self.assertIn('_openResolutionDialog(context)',ui)
        self.assertIn("onCommand('zoom/$target')",ui)
        self.assertIn('adjust(0)',ui)
        for command in ['quality/360','quality/480','quality/720','quality/768','quality/1080']:
            self.assertIn(command,ui)
        self.assertNotIn("_action(context, Icons.refresh, 'Atualizar'",ui)
        self.assertNotIn("_action(context, Icons.zoom_out, 'Zoom −'",ui)
        self.assertNotIn("_action(context, Icons.zoom_in, 'Zoom +'",ui)
    def test_help_status_and_camera_name_cleanup(self):
        ui=read('lib/widgets/mcrp_remote_controls.dart')
        self.assertIn('Icons.help_outline',ui)
        self.assertIn('_showControlHelp(context)',ui)
        self.assertIn("_transmitting ? 'Parar' : 'Iniciar'",ui)
        self.assertNotIn('Gravação desligada',ui)
        self.assertNotIn('FPS medido:',ui)
        self.assertNotIn('Transmissão pausada.',ui)
        stage=read('lib/screens/monitor_screen_multicamera.dart')
        self.assertIn('portraitEmbedded && _controller.sourceConfig.type != VideoSourceType.remotePhone',stage)
    def test_lite0_default_and_auto_order(self):
        models=read('lib/models/video_source_config.dart')
        settings=read('lib/services/app_settings_service.dart')
        assets=read('lib/services/object_detection_assets.dart')
        self.assertIn('this.detectorModel = DetectorModelPreference.efficientDetLite0', models)
        self.assertIn('orElse: () => DetectorModelPreference.efficientDetLite0', settings)
        self.assertIn("'version': 9",settings)
        self.assertIn('profileVersion < 9',settings)
        self.assertIn('DetectorModelPreference.automatic || DetectorModelPreference.efficientDetLite0 => 2',assets)
        self.assertIn('DetectorModelPreference.yolo26s => 0',assets)
        self.assertIn('modelIndex++ < firstIndex',assets)
    def test_metadata(self):
        self.assertIn('version: 1.0.293+293',read('pubspec.yaml'))
        self.assertIn("AppBuildVersion(version: '1.0.293', build: 293)",read('lib/services/update_news_catalog.dart'))
        self.assertTrue((ROOT/'RELEASE-1.0.293.md').exists())

if __name__ == '__main__': unittest.main()
