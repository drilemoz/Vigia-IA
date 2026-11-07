"""Prevenção: painel de pontos maior sem mudança no fluxo de consultas."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NearbyPointsPanelHeight368(unittest.TestCase):
    def test_height_and_responsive_cap(self):
        text = (ROOT / 'lib/screens/map_monitoring_screen.dart').read_text('utf8')
        panel = text.split('  Future<void> _showNearbyPoints() async {', 1)[1].split('  String _formatSearchDistance(', 1)[0]
        self.assertIn('maxHeightFactor: 0.92,', panel)
        self.assertIn('height: filtered.isEmpty && !busy ? 570 : 690,', panel)
        self.assertIn('Expanded(', panel)
        self.assertIn("tooltip: 'Fechar'", panel)
        self.assertIn("label: const Text('Atualizar')", panel)
        self.assertIn("label: const Text('Salvar pacote')", panel)
        self.assertIn('service.offlinePackages.isNotEmpty', panel)
        self.assertNotIn('height: filtered.isEmpty && !busy ? 420 : 650,', panel)

    def test_version_and_release(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text('utf8')
        self.assertIn('version: 1.0.369+369', pubspec)
        self.assertTrue((ROOT / 'RELEASE-1.0.368.md').is_file())
        self.assertIn('1.0.369', (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf8'))

if __name__ == '__main__':
    unittest.main()
