import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/diagnostic_ui_interaction_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vigiaia/native');

  testWidgets('toque normal grava area aproximada sem textos', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(MaterialApp(
      home: DiagnosticUiInteractionCapture(
        child: Scaffold(
          body: Center(child: FilledButton(
            onPressed: () {},
            child: const Text('Abrir menu'),
          )),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir menu'));
    await tester.pump();
    final interactions = calls.where((c) => c.method == 'diagnosticEvent');
    expect(interactions, isNotEmpty);
    final details = interactions.last.arguments as Map<Object?, Object?>;
    expect(details['source'], 'UI');
    expect(details['urgent'], isTrue);
    final description = details['detail'] as String;
    expect(description, contains('area=toque'));
    expect(description, isNot(contains('Abrir menu')));
    expect(description, isNot(contains('password')));
  });
}

