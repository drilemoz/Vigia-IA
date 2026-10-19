"""Contratos 294: UI compacta, LAN e diagnóstico pontual."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def src(path): return (ROOT/path).read_text(encoding='utf8')
class Redesign294(unittest.TestCase):
  def test_navigation_five_settings_top_right(self):
    nav=src('lib/widgets/main_navigation_bar.dart')
    self.assertNotIn("label: 'Ajustes'",nav)
    self.assertEqual(nav.count("label: '"),5)
    self.assertIn("tooltip: 'Configurações gerais'",src('lib/screens/monitor_screen.dart'))
    self.assertIn('appBar: AppBar(',src('lib/screens/map_workspace_shell.dart'))
    self.assertIn('return Scaffold(',src('lib/screens/settings_screen.dart'))
    self.assertNotIn('currentIndex: 5',src('lib/screens/settings_screen.dart'))
  def test_video_control_combines_fps_quality_and_torch(self):
    ui=src('lib/widgets/mcrp_remote_controls.dart')
    for part in ['_openVideoDialog(context)','_openTorchDialog(context)',
        "'fps/30'", "'quality/1080'", "'torch/record'", "Icons.face_outlined"]:
      self.assertIn(part,ui)
    self.assertNotIn("_setting(context, 'FPS'",ui)
    self.assertNotIn("_setting(context, 'Lanterna'",ui)
  def test_video_paused_and_times_from_real_transmitter(self):
    ui=src('lib/screens/monitor_screen_multicamera.dart')
    self.assertIn("remote['x-transmitting'] == '0'",ui)
    self.assertIn("data['x-recording-seconds']", src('lib/screens/monitor_screen_mcrp_support.dart'))
    self.assertIn('McrpLiveStatusCache.duration',src('lib/screens/monitor_screen_mcrp_support.dart'))
    self.assertIn("_mcrpStatusChip('AO VIVO'",ui)
    self.assertNotIn("_monitorMenu(),",ui)
  def test_tcp_8765_does_not_bypass_qr(self):
    scanner=src('lib/services/lan_camera_subnet_scanner.dart')
    lan=src('lib/screens/multi_camera_screen_lan_discovery.dart')
    self.assertIn('8765',scanner)
    self.assertIn('Possível transmissor Vigia IA; confirmar via QR',scanner)
    self.assertIn('selected.port == 8765',lan)
    self.assertIn('await _scanPhoneQr()',lan)
    self.assertIn('range.gateway',lan)
    self.assertIn('sendVigiaProbe()',src('lib/services/lan_camera_discovery_service.dart'))
    native=src('android/app/src/main/kotlin/com/vigiaia/app/LanScanSupport.kt')
    self.assertIn('it.isDefaultRoute',native)
    self.assertEqual(native,src('tool/android/LanScanSupport.kt'))
  def test_rtsp_prefill_and_diagnostic(self):
    editor=src('lib/screens/multi_camera_screen_editor.dart')
    self.assertIn('safeAddress.isNotEmpty',editor)
    self.assertIn('initialAddress!.trim()',editor)
    self.assertIn('exportToDownloads()',src('lib/screens/monitor_screen_ai_tools.dart'))
    self.assertIn('Downloads/Vigia IA',src('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt'))
  def test_version(self):
    self.assertIn('version: 1.0.304+304',src('pubspec.yaml'))
    self.assertTrue((ROOT/'RELEASE-1.0.304.md').exists())
if __name__=='__main__': unittest.main()
