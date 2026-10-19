"""Checks that gallery reuses authenticated MCRP media and preserves originals."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def source(path): return (ROOT / path).read_text('utf-8')

class RemoteGallery306(unittest.TestCase):
    def test_six_destinations_with_explicit_gallery(self):
        nav = source('lib/widgets/main_navigation_bar.dart')
        route = source('lib/widgets/main_navigation_routes.dart')
        self.assertEqual(nav.count("label: '"), 6)
        self.assertIn("label: 'Galeria'", nav)
        self.assertIn('4 => const RemoteGalleryScreen()', route)
        self.assertIn('5 => const MapWorkspaceShell()', route)
        self.assertIn('currentIndex: 5', source('lib/screens/map_workspace_shell.dart'))
        self.assertIn('currentIndex: 4', source('lib/screens/remote_gallery_screen.dart'))
        self.assertIn('findsNWidgets(6)', source('test/main_navigation_bar_test.dart'))

    def test_gallery_ui_mimics_existing_remote_multimedia(self):
        ui = source('lib/screens/remote_gallery_screen.dart')
        for name in ('Aparelhos', 'Atualizar', 'Endereço', 'Ler QR', 'Recebidos',
                     'Fotos', 'Vídeos', 'Baixar selecionados', 'Cancelar',
                     'McrpSavedCamerasStore', 'RemoteGalleryStorage', 'MobileScanner'):
            self.assertIn(name, ui)
        self.assertIn('client.info()', ui.replace('next.info()', 'client.info()'))
        self.assertIn('client.media()', ui)
        self.assertIn('publishCameraMedia', ui)
        self.assertNotIn('record/start', ui)
        self.assertNotIn('File.delete(', ui)
        self.assertIn('McrpAddress.parse', ui)

    def test_media_stream_security_and_atomic_copy(self):
        server = source('android/app/src/main/kotlin/com/minhacamera/PhoneCameraServer.kt')
        client = source('lib/services/mcrp_client.dart')
        store = source('lib/services/remote_gallery_storage.dart')
        native = source('android/app/src/main/kotlin/com/minhacamera/PhoneRemoteLibrary.kt')
        self.assertIn('GET $mcrpRoot/media', server)
        self.assertIn('mediaOpen?.invoke(id)', server)
        self.assertIn('fun open(id: String)', native)
        self.assertIn('McrpAddress.parse', source('lib/services/mcrp_saved_cameras_store.dart'))
        for value in ('isCancelled', 'onProgress', '.part', 'rename(file.path)', 'partial.delete()', 'mediaFile(item.id)'):
            self.assertIn(value, client)
        for value in ('sha256.convert', 'localCopy', 'alreadySaved', 'received', 'vr_', 'directoryProvider'):
            self.assertIn(value, store)
        self.assertTrue((ROOT/'test/remote_gallery_storage_test.dart').exists())

    def test_version(self):
        self.assertIn('version: 1.0.308+308', source('pubspec.yaml'))
        self.assertTrue((ROOT/'RELEASE-1.0.308.md').is_file())

if __name__ == '__main__': unittest.main()
