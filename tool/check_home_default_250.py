#!/usr/bin/env python3
"""Assegura que o modo normal abre Home sem destruir acesso ao mapa."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
app = (root / 'lib/app/app.dart').read_text()
launch = (root / 'lib/screens/launch_mode_screen.dart').read_text()
home = (root / 'lib/screens/home_screen_redesign.dart').read_text()
imports = (root / 'lib/screens/home_screen.dart').read_text()
assert 'AppLaunchMode.normal => _resumeMonitoring' in app
assert '? const HomeScreen(resumeMonitorOnLoad: true)' in app
assert ': const HomeScreen(),' in app
assert 'AppLaunchMode.bike => const MapWorkspaceShell()' in app
assert 'AppLaunchMode.normal => widget.startMonitorOnLoad' in launch
assert ': const HomeScreen(),' in launch
assert 'AppLaunchMode.bike => const MapWorkspaceShell()' in launch
assert 'navigateToMainDestination(context, index, currentIndex: 0)' in home
assert "import 'map_workspace_shell.dart';" not in imports
assert "label: 'Mapas'" in (root / 'lib/widgets/main_navigation_bar.dart').read_text()
assert "import 'mcrp_camera_screen.dart';" not in imports
assert "onTap: () => _openScreen(const McrpCameraScreen())," not in home
assert "title: 'Minha Câmera'" not in home
for expected in ('Monitorar', 'Transmitir', 'Receber', 'ESP32',
                 'Monitoramento atual', 'Estado do sistema'):
    assert expected in home, expected
assert home.count('VigiaModeCard(') == 4
assert '_buildQuickActions' not in home  # os destinos já estão na barra inferior
print('OK: Home 282, modos e navegação principal, Bike e retomada.')
