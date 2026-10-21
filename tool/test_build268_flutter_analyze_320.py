"""Protege os dois avisos fatais reais do Flutter Analyze no build 268."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


class Build268Analyzer320(unittest.TestCase):
    def test_coordinate_guard_requires_braces(self):
        dart = source('lib/services/automatic_diagnostics_service.dart')
        self.assertRegex(dart, re.compile(
            r'if\s*\(row < 0 \|\| row >= rows\.length \|\|'
            r'\s*column < 0 \|\| column >= columns\.length\)'
            r'\s*\{\s*return;\s*\}', re.S))
        self.assertNotRegex(dart, r'column >= columns\.length\)\s*return;')

    def test_pointer_kind_uses_gestures_without_redundant_import(self):
        dart = source('lib/widgets/diagnostic_ui_interaction_capture.dart')
        self.assertIn("import 'package:flutter/gestures.dart';", dart)
        self.assertIn('PointerDeviceKind.touch', dart)
        self.assertNotIn("import 'dart:ui'", dart)

    def test_version_and_release(self):
        self.assertIn('version: 1.0.320+320', source('pubspec.yaml'))
        self.assertTrue((ROOT / 'RELEASE-1.0.320.md').is_file())
        self.assertTrue((ROOT / 'VALIDATION-1.0.320.md').is_file())


if __name__ == '__main__':
    unittest.main()
