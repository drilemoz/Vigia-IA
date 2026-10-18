from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def read(file):
    return (ROOT / file).read_text(encoding='utf-8')

class MainNavigationSix279(unittest.TestCase):
    def test_six_destinations(self):
        bar = read('lib/widgets/main_navigation_bar.dart')
        for name in ('Início', 'Histórico', 'Ao vivo', 'Câmeras', 'Mapas', 'Ajustes'):
            self.assertIn(f"label: '{name}'", bar)
        self.assertIn('hideNavigation', bar)
        self.assertIn('NavigationRail', bar)

    def test_all_primary_surfaces(self):
        for filename, index in [
            ('lib/screens/home_screen_redesign.dart', 0),
            ('lib/screens/events_screen.dart', 1),
            ('lib/screens/monitor_screen.dart', 2),
            ('lib/screens/multi_camera_screen.dart', 3),
            ('lib/screens/map_workspace_shell.dart', 4),
            ('lib/screens/settings_screen.dart', 5),
        ]:
            self.assertIn(f'currentIndex: {index}', read(filename), filename)
        self.assertIn('hideNavigation: _fullscreen', read('lib/screens/monitor_screen.dart'))

    def test_single_routing_contract(self):
        routes = read('lib/widgets/main_navigation_routes.dart')
        self.assertIn('4 => const MapWorkspaceShell()', routes)
        self.assertIn('5 => const SettingsScreen()', routes)
        self.assertIn('2 => const HomeScreen(startMonitorOnLoad: true)', routes)
        self.assertIn('pushAndRemoveUntil', routes)

if __name__ == '__main__':
    unittest.main()
