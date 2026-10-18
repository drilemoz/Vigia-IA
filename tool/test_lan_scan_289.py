"""Prevenção de regressões da busca híbrida baseada no Minha Câmera 1.4.76."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):return (ROOT/name).read_text(encoding='utf-8')
class LanDiscovery289(unittest.TestCase):
    def test_tcp_well_known_ports_and_bounded_concurrency(self):
        src=source('lib/services/lan_camera_subnet_scanner.dart')
        for value in ('554','8554','10554','8555','7447','80','8080','5000'):
            self.assertIn(value,src)
        self.assertIn('min(24, hosts.length)',src)
        self.assertIn('take(254)',src)
        self.assertIn('Duration(milliseconds: 320)',src)
    def test_probe_never_authenticates_and_confirms_protocol(self):
        src=source('lib/services/lan_camera_subnet_scanner.dart')
        self.assertIn('OPTIONS rtsp://',src)
        self.assertIn("startsWith('RTSP/')",src)
        self.assertIn("startsWith('HTTP/')",src)
        self.assertIn('TCP aberto (não verificado)',src)
        self.assertNotIn('Authorization:',src)
    def test_android_wifi_subnet_and_no_cellular(self):
        src=source('android/app/src/main/kotlin/com/vigiaia/app/LanScanSupport.kt')
        self.assertIn('TRANSPORT_WIFI',src)
        self.assertIn('linkAddresses',src)
        self.assertIn('prefixLength',src)
        self.assertIn('swlan',src)
        self.assertIn('last - first + 1 > 254',src)
        self.assertIn('it != local',src)
        self.assertEqual(src,source('tool/android/LanScanSupport.kt'))
    def test_multicast_lock_scoped_with_android_manifest(self):
        src=source('android/app/src/main/kotlin/com/vigiaia/app/LanScanSupport.kt')
        self.assertIn('createMulticastLock',src)
        self.assertIn('multicastLock?.acquire()',src)
        self.assertIn('multicastLock?.let { if (it.isHeld) it.release() }',src)
        self.assertIn('CHANGE_WIFI_MULTICAST_STATE',source('tool/AndroidManifest.xml'))
        self.assertEqual(source('android/app/src/main/AndroidManifest.xml'),source('tool/AndroidManifest.xml'))
    def test_ci_installs_helper_even_when_android_recreated(self):
        bootstrap=source('tool/bootstrap_android.sh')
        self.assertIn('cp "$ROOT/tool/android/LanScanSupport.kt" "$KOTLIN_DIR/LanScanSupport.kt"',bootstrap)
        main=source('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        self.assertIn('"lanScanRange" ->',main)
        self.assertIn('"lanMulticastLock" ->',main)
        self.assertEqual(main,source('tool/android/MainActivity.kt'))
    def test_ui_permission_progress_cancel_and_not_fake_rtsp(self):
        ui=source('lib/screens/multi_camera_screen_lan_discovery.dart')
        self.assertIn('requestLocalNetworkPermission()',ui)
        self.assertIn('checked = value',ui)
        self.assertIn('cancel.cancel()',ui)
        self.assertIn('LanCameraKind.rtsp',ui)
        self.assertIn('exige pareamento por QR',ui)
        self.assertIn('await _scanPhoneQr()',ui)
        self.assertIn('final port = selected.kind == LanCameraKind.rtsp',ui)
    def test_onvif_udp_parallel_tcp(self):
        src=source('lib/screens/multi_camera_screen_lan_discovery.dart')
        self.assertIn('Future.wait(<Future<void>>[',src)
        self.assertIn('LanCameraDiscoveryService.discover(',src)
        self.assertIn('LanCameraSubnetScanner.scan(',src)
        self.assertIn('await LanCameraSubnetScanner.multicast(false);',src)
        self.assertIn('discovered.indexWhere((old) => old.host == candidate.host)',src)
        self.assertIn('priority(candidate) > priority(discovered[index])',src)
    def test_no_auto_pair_token_or_password_in_discovery(self):
        src=source('lib/services/lan_camera_discovery_service.dart')
        self.assertIn("_vigiaProbe = 'VIGIAIA_DISCOVER_V1'",src)
        self.assertIn('targetBroadcasts',src)
        self.assertNotIn('password=',src)
        self.assertNotIn('/live/?token=',src)
if __name__=='__main__':unittest.main()
