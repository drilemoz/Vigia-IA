"""Regressoes estruturais do ciclo de vida MBTiles e MapLibre 3D (1.0.343).

Testes estaticos nao comprovam comportamento Flutter/Android em dispositivo.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return (ROOT / name).read_text('utf-8')


class MapLifecycle339(unittest.TestCase):
    def test_provider_keeps_db_during_flutter_map_dispose(self):
        src = read('lib/services/retained_mbtiles_tile_provider.dart')
        dispose = src.split('void dispose() {', 1)[1].split('\n  }', 1)[0]
        release = src.split('void release() {', 1)[1].split('\n  }', 1)[0]
        close = src.split('void _close() {', 1)[1].split('\n  }', 1)[0]
        self.assertNotIn('_delegate.dispose()', dispose)
        self.assertIn('Timer(retirementGrace, _close)', release)
        self.assertIn('_delegate.dispose()', close)
        self.assertIn('retirementGrace = Duration(seconds: 45)', src)

    def test_both_screens_own_and_release_their_providers(self):
        for name, token in [
            ('lib/screens/map_monitoring_screen.dart', '_offlineTileProvider'),
            ('lib/screens/monitor_screen_offline_map.dart', '_miniOfflineTileProvider'),
        ]:
            src = read(name)
            self.assertIn('RetainedMbTilesTileProvider.fromPath(', src)
            self.assertIn(f'{token}?.release();', src)
            self.assertNotIn(f'{token}?.dispose();', src)
            self.assertIn('provider?.release();', src)
        self.assertIn('_miniOfflineTileProvider?.release();', read('lib/screens/monitor_screen.dart'))

    def test_deleting_package_notifies_map_before_physical_removal(self):
        src = read('lib/services/offline_map_service.dart')
        body = src.split('Future<void> deletePackage(String id) async {', 1)[1].split('\n  Future<void> _cleanupOrphanedMbTiles()', 1)[0]
        self.assertLess(body.index('_packages.removeAt(index)'), body.index('await _persist()'))
        self.assertLess(body.index('notifyListeners();'), body.index('deleteWhenUnused(item.path)'))
        self.assertNotIn('await file.delete();', body)
        self.assertIn('await _cleanupOrphanedMbTiles();', src)
        self.assertIn("entry.path.endsWith('.mbtiles')", src)
        provider = read('lib/services/retained_mbtiles_tile_provider.dart')
        self.assertIn('(_openByPath[path]?.isNotEmpty ?? false)', provider)

    def test_android_map_uses_texture_tlhc_without_invisible_platform_view(self):
        widget = read('lib/widgets/map_navigation_3d_view.dart')
        screen = read('lib/screens/map_monitoring_screen.dart')
        self.assertIn('androidTextureMode: true,', widget)
        self.assertIn('androidMode: ml.AndroidPlatformViewMode.tlhc_hc,', widget)
        self.assertNotIn('androidMode: ml.AndroidPlatformViewMode.hc,', widget)
        self.assertNotIn('child: AnimatedOpacity(\n                      opacity: navigation3dActive ? 1 : 0', screen)
        self.assertIn('if (!navigation3dActive)', screen)

    def test_progress_does_not_reset_three_dimensional_renderer(self):
        screen = read('lib/screens/map_monitoring_screen.dart')
        body = screen.split('void _onOfflineMapsChanged() {', 1)[1].split('\n  void _syncOfflineTileProvider()', 1)[0]
        self.assertIn('if (oldMode != _offlineMaps.mode)', body)
        network = read('lib/screens/map_monitoring_offline_support.dart')
        self.assertIn('if (previous.isOffline != current.isOffline)', network)

    def test_release_and_version_are_sequential(self):
        self.assertIn('version: 1.0.353+353', read('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.348.md').is_file())
        self.assertTrue((ROOT / 'VALIDATION-1.0.348.md').is_file())


if __name__ == '__main__':
    unittest.main()
