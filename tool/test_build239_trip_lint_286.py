"""Build 239: prevenir lints fatais em condicionais no Planejamento."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'lib/screens/trip_planning_screen.dart'

class Build239TripLint286(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8')

    def test_gps_error_conditional_is_braced(self):
        self.assertRegex(self.source, r'if \(mounted\) \{\s*setState\(\(\) => _message')
        gps_catch = self.source[self.source.index('Não foi possível obter uma posição GPS atual.')-160:self.source.index('Não foi possível obter uma posição GPS atual.')+130]
        self.assertNotRegex(gps_catch, r'if \(mounted\)\s+setState\(\(\) => _message')

    def test_preferences_update_is_braced(self):
        self.assertRegex(self.source, r'if \(draft != null\) \{\s*setState\(\(\) => _draft')
        self.assertNotRegex(self.source, r'if \(draft != null\)\s+setState\(')

    def test_delete_update_is_braced(self):
        block = self.source[self.source.index('Future<void> _delete('):self.source.index('void _loadTrip(')]
        self.assertRegex(block, r'if \(mounted\) \{\s*setState\(\(\) \{')
        self.assertRegex(block, r'if \(_draft\?\.id == trip\.id\) \{')
        self.assertNotRegex(block, r'if \(mounted\)\s+setState\(')

if __name__ == '__main__':
    unittest.main()
