"""Guarda estrutural para os 3 infos da análise estática do APK 263.

Não substitui `flutter analyze --fatal-infos --fatal-warnings` do workflow.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Build263AnalyzerRegression(unittest.TestCase):
    def test_diagnostics_service_has_no_redundant_typed_data_import(self):
        source = (ROOT / 'lib/services/automatic_diagnostics_service.dart').read_text('utf-8')
        self.assertNotIn("import 'dart:typed_data';", source)
        self.assertIn("import 'package:flutter/services.dart';", source)
        self.assertIn('Uint8List.fromList(utf8.encode(text))', source)

    def test_dart_redaction_test_uses_package_import_and_no_print(self):
        source = (ROOT / 'tool/dart/diagnostic_redactor_test.dart').read_text('utf-8')
        self.assertIn("import 'package:vigiaia/utils/diagnostic_redactor.dart';", source)
        self.assertNotIn("import '../../lib/", source)
        self.assertIn('stdout.writeln(', source)
        self.assertNotIn('print(', source)
        self.assertIn('DiagnosticRedactor.text(input)', source)
        self.assertIn('DiagnosticRedactor.field(', source)

    def test_version_bumped_and_release_documented(self):
        self.assertIn('version: 1.0.321+321', (ROOT / 'pubspec.yaml').read_text('utf-8'))
        self.assertTrue((ROOT / 'RELEASE-1.0.321.md').exists())


if __name__ == '__main__':
    unittest.main()
