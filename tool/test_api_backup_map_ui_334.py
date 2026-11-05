"""Contratos locais do backup de APIs e UX de mapas da 1.0.343.
Não equivalem a teste Android/SAF ou flutter analyze.
"""
import unittest
from pathlib import Path
R = Path(__file__).resolve().parents[1]

def read(name): return (R/name).read_text('utf-8')

class ApiBackupAndMapUi335(unittest.TestCase):
    def test_version(self):
        self.assertIn('version: 1.0.352+352', read('pubspec.yaml'))
        self.assertTrue((R/'RELEASE-1.0.348.md').is_file())
    def test_api_central_has_two_real_actions(self):
        s=read('lib/screens/api_services_setup_screen.dart')
        for item in ('Exportar APIs','Importar APIs','_transferApiKeys','_askBackupPassword',
                     'Confirmar importação','_refresh()','senha'):
            self.assertIn(item,s)
    def test_encrypted_portable_format(self):
        kt=read('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
        for x in ('VIGAAPI1','PBKDF2WithHmacSHA256','AES/GCM/NoPadding',
                  'apiArchiveIterations = 210_000','cipher.updateAAD(header)',
                  'GCMParameterSpec(128, nonce)','copyOfRange(0, 8).contentEquals',
                  'bytes.size in 53..65536', 'beginApiArchiveImport',
                  'encryptApiArchive', 'decryptApiArchive'):
            self.assertIn(x,kt)
        self.assertEqual(kt,read('tool/android/MainActivity.kt'))
    def test_export_only_local_secrets(self):
        s=read('lib/services/api_credentials_backup_service.dart')
        for k in ('gemini','googleMapsUser','stadia','geoapify','openrouteservice'):
            self.assertIn("'"+k+"'", s)
        self.assertNotIn('googleMapsBuildKey',s)
        self.assertNotIn('MAPS_API_KEY',s.replace('MAPS_API_KEY do manifesto', ''))
        self.assertIn('encrypted',s)
        self.assertIn('Confirmar',read('lib/screens/api_services_setup_screen.dart'))
        self.assertIn('keys.containsKey',s)
    def test_no_unencrypted_fallback(self):
        s=read('lib/services/api_credentials_backup_service.dart')
        self.assertNotIn('base64Encode(',s)
        self.assertIn('encryptApiArchive',s)
        self.assertIn('decryptApiArchive',s)
        self.assertIn('saveBytesWithPicker',s)
    def test_map_has_single_top_bar(self):
        shell=read('lib/screens/map_workspace_shell.dart')
        self.assertIn('workspaceHeaderHeight: 0',shell)
        self.assertNotIn("child: Text('Mapas'",shell)
        screen=read('lib/screens/map_monitoring_screen.dart')
        self.assertIn('_MapWorkspaceModeShortcut',screen)
        self.assertIn('_MapQuickViewBar',screen)
        self.assertIn("tooltip: 'Aparência e camadas do mapa'",screen)
        self.assertNotIn("title: const Text('Modo do mapa')",screen)
    def test_search_timeout_and_local_fallback(self):
        dest=read('lib/services/map_destination_search_service.dart')
        pois=read('lib/services/route_explorer_service.dart')
        screen=read('lib/screens/map_monitoring_screen.dart')
        self.assertIn('allowMirror: true',dest)
        self.assertIn(').timeout(const Duration(seconds: 10));',dest)
        self.assertIn(').timeout(const Duration(seconds: 8));',dest)
        self.assertIn('if (revision == _searchRevision) _setSearchLoading(false)',dest)
        self.assertIn('.timeout(const Duration(seconds: 18))',pois)
        self.assertIn('looksLikeNaturalLanguage',screen)
        self.assertIn('Gemini indisponível. Pesquisa normal ativada.',screen)

if __name__=='__main__': unittest.main()
