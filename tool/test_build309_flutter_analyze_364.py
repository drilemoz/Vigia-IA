"""APK 309: regressão estrutural do operador nulo redundante (não substitui Flutter Analyze)."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
SCREEN=(ROOT/'lib/screens/trip_planning_screen.dart').read_text(encoding='utf-8')

class FlutterAnalyze309(unittest.TestCase):
    def test_stop_note_condition_still_guards_nonnull_record(self):
        self.assertRegex(SCREEN, r'if \(checkValid && savedCheck!\.notes\.isNotEmpty\)')
        self.assertIn("Text('Nota offline: ${savedCheck.notes}'", SCREEN)

    def test_no_nullaware_access_after_nonnull_check(self):
        self.assertNotIn('savedCheck?.notes', SCREEN)
        self.assertNotIn("savedCheck?.notes ?? ''", SCREEN)

    def test_current_metadata_and_release_are_in_sync(self):
        self.assertRegex((ROOT/'pubspec.yaml').read_text(), r'(?m)^version: 1\.0\.\d+\+\d+$')
        self.assertTrue((ROOT/'RELEASE-1.0.364.md').is_file())

if __name__=='__main__':
    unittest.main()
