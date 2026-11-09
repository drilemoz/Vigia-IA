"""Regressão do Flutter analyze do workflow Android APK 317."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
DART = ROOT / "lib/screens/trip_planning_screen.dart"


class Build317FlutterAnalyze372(unittest.TestCase):
    def test_discard_guard_is_braced(self):
        source = DART.read_text(encoding="utf-8")
        self.assertRegex(source, re.compile(
            r"if\s*\(discard\s*==\s*true\s*&&\s*mounted\)\s*\{\s*setState\s*\(\s*\(\)\s*\{",
        ))
        self.assertNotRegex(source, re.compile(
            r"if\s*\(discard\s*==\s*true\s*&&\s*mounted\)\s*setState"
        ))

    def test_discard_keeps_resets(self):
        source = DART.read_text(encoding="utf-8")
        pos = source.index("if (discard == true && mounted) {")
        segment = source[pos:pos + 200]
        self.assertIn("_draft = null;", segment)
        self.assertIn("_selectedDayIndex = 0;", segment)
        self.assertIn("setState(() {", segment)

    def test_release_version(self):
        self.assertIn("version: 1.0.373+373", (ROOT / "pubspec.yaml").read_text())


if __name__ == "__main__":
    unittest.main()
