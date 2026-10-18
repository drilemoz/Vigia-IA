import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/mcrp_remote_controls.dart';

void main() {
  testWidgets('controles MCRP usam ações remotas e zoom absoluto', (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: McrpControlPanel(
        status: const {
          'x-recording': '0', 'x-eco': '0', 'x-camera-facing': '0',
          'x-zoom-supported': '1', 'x-zoom-percent': '40',
          'x-torch-supported': '1', 'x-torch-enabled': '0', 'x-torch-mode': 'off',
          'x-fps-target': '15', 'x-fps-measured': '12', 'x-battery-level': '84',
        },
        working: false,
        onCommand: (action) async => commands.add(action),
      ),
    ))));
    await tester.tap(find.text('Iniciar REC'));
    await tester.pump();
    await tester.tap(find.text('Zoom +'));
    await tester.pump();
    await tester.tap(find.text('Lanterna'));
    await tester.pump();
    expect(commands, ['record/start', 'zoom/50', 'torch/30']);
    expect(find.text('Zoom: 40%'), findsOneWidget);
    expect(find.text('FPS medido: 12'), findsOneWidget);
    expect(find.text('Gravação desligada'), findsOneWidget);
    expect(find.text('Codec'), findsNothing);
  });

  testWidgets('REC ativo muda o botão para parada remota', (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: McrpControlPanel(
      status: const {'x-recording': '1'},
      working: false,
      onCommand: (action) async => commands.add(action),
    ))));
    expect(find.text('Gravando no transmissor'), findsOneWidget);
    await tester.tap(find.text('Parar REC'));
    await tester.pump();
    expect(commands, ['record/stop']);
  });

  testWidgets('lanterna e zoom indisponíveis ficam desabilitados', (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: McrpControlPanel(
      status: const {'x-torch-supported': '0', 'x-zoom-supported': '0'},
      working: false,
      onCommand: (action) async => commands.add(action),
    ))));
    await tester.tap(find.text('Lanterna'));
    await tester.tap(find.text('Zoom +'));
    await tester.pump();
    await tester.tap(find.text('Iniciar REC'));
    await tester.pump();
    expect(commands, isEmpty);
  });
}
