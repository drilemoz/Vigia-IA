import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/core/app_metadata.dart';

void main() {
  test('metadados publicos do Vigia IA estao sincronizados', () {
    expect(AppMetadata.name, 'Vigia IA');

    // O pubspec e a origem unica da versao; evitar expectativas obsoletas.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml deve conter versao e build');
    expect(AppMetadata.version, match!.group(1));
    expect(AppMetadata.build, int.parse(match.group(2)!));
  });
}
