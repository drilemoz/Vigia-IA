"""Regression checks for network, GPS and safe recovery (1.0.348)."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def read(name):
    return (ROOT / name).read_text(encoding="utf-8")

class ConnectivityEnergySecurity348(unittest.TestCase):
    def test_https_probe_not_dns(self):
        source = read("lib/services/map_connectivity_service.dart")
        self.assertIn("client.getUrl(endpoint)", source)
        self.assertIn("request.followRedirects = false", source)
        self.assertIn("statusCode == HttpStatus.noContent", source)
        self.assertNotIn("InternetAddress.lookup(", source)
        self.assertIn("failuresBeforeOffline", source)

    def test_gps_profile_switch_is_demand_driven(self):
        route = read("lib/services/map_route_service.dart")
        location = read("lib/services/location_tracking_service.dart")
        policy = read("lib/services/map_performance_policy.dart")
        self.assertIn("_configureLocationStream", route)
        self.assertIn("_acceptPosition(await _location.currentPosition());", route)
        self.assertIn("_streamHighAccuracy == highAccuracy", route)
        self.assertIn("MapPerformancePolicy.needsPreciseGps", route)
        self.assertIn("LocationAccuracy.medium", location)
        self.assertIn("passiveGpsDistanceFilterMeters = 35", policy)
        self.assertIn("gpsDistanceFilterMeters = 8", policy)

    def test_exported_system_receiver_and_private_app_receiver(self):
        manifest = read("android/app/src/main/AndroidManifest.xml")
        self.assertIn('android:name=".MonitorBootRecoveryReceiver"', manifest)
        self.assertIn('android:name=".MonitorRecoveryReceiver"\n            android:enabled="true"\n            android:exported="false"', manifest)
        receiver = read("android/app/src/main/kotlin/com/vigiaia/app/MonitorRecoveryReceiver.kt")
        boot = read("android/app/src/main/kotlin/com/vigiaia/app/MonitorBootRecoveryReceiver.kt")
        self.assertIn("intent?.action != ACTION_RECOVER_MONITOR", receiver)
        self.assertIn("Intent.ACTION_BOOT_COMPLETED", boot)
        self.assertIn("Intent.ACTION_MY_PACKAGE_REPLACED", boot)
        self.assertEqual(receiver, read("tool/android/MonitorRecoveryReceiver.kt"))
        self.assertEqual(boot, read("tool/android/MonitorBootRecoveryReceiver.kt"))
        self.assertEqual(manifest, read("tool/AndroidManifest.xml"))
        self.assertIn("MonitorBootRecoveryReceiver.kt", read("tool/bootstrap_android.sh"))

    def test_ci_cancel_automatic_not_manual(self):
        ci = read(".github/workflows/android-apk.yml")
        self.assertIn("group: vigiaia-apk-${{ github.ref }}-${{ github.event_name }}", ci)
        self.assertIn("cancel-in-progress: ${{ github.event_name == 'push' }}", ci)
        self.assertIn("flutter analyze --fatal-infos --fatal-warnings", ci)

    def test_hud_limits_idle_rebuild_without_hiding_stale_progress(self):
        source = read("lib/screens/map_monitoring_screen.dart")
        policy = read("lib/services/map_hud_refresh_policy.dart")
        self.assertIn("recording: _routeState.recording", source)
        self.assertIn("staleProgress || refreshDevice", policy)
        self.assertIn("_navigationProgress = null", source)
        self.assertIn("tick: ++_hudFreshnessTicks", source)

if __name__ == "__main__":
    unittest.main()
