import 'dart:io';

import 'package:vigiaia/utils/diagnostic_redactor.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  const secret = 'fictionalSecret@987';
  const input =
      'FormatException: Invalid character (at character 7)\ncamera:$secret\n      ^\n\n#0 Uri.replace\n#1 CameraEditor.save';
  final safe = DiagnosticRedactor.text(input);
  check(!safe.contains(secret), 'legacy FormatException source leaked');
  check(safe.contains('#1 CameraEditor.save'), 'stack must be preserved');
  check(
    DiagnosticRedactor.field('password', secret) == '[omitido]',
    'context key',
  );
  check(
    DiagnosticRedactor.field('fps', 24) == '24',
    'ordinary metrics preserved',
  );
  for (final value in [
    'rtsp://camera:$secret@192.0.2.1/live',
    'https://example.test/?token=$secret',
    'password="$secret"',
    "senha='$secret'",
    'token=$secret',
    '"password": "$secret"',
  ]) {
    check(
      !DiagnosticRedactor.text(value).contains(secret),
      'credential leaked',
    );
  }
  stdout.writeln(
    'PASS: Dart redaction, legacy source scrub, preserved metrics and stack',
  );
}
