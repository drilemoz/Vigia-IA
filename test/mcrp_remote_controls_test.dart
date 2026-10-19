import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/mcrp_remote_controls.dart';

void main() {
  testWidgets('zoom, vídeo e lanterna usam diálogos e preservam comandos', (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: McrpControlPanel(
        status: const {
          'x-transmitting': '1', 'x-recording': '0', 'x-eco': '0',
          'x-camera-facing': '0', 'x-quality-profile': '720p',
          'x-zoom-supported': '1', 'x-zoom-percent': '40',
          'x-torch-supported': '1', 'x-torch-enabled': '0', 'x-torch-mode': 'off',
          'x-fps-target': '15', 'x-fps-measured': '12', 'x-battery-level': '84',
        },
        working: false,
        onCommand: (action) async { commands.add(action); },
      ),
    ))));
    await tester.tap(find.text('Iniciar REC'));
    await tester.pump();
    await tester.tap(find.text('Zoom'));
    await tester.pumpAndSettle();
    expect(find.text('Zoom da câmera'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar zoom'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);
    await tester.tap(find.text('Tamanho original (1×)'));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    // Na 1.0.297, o card Vídeo agrupa resolução e FPS.
    await tester.tap(find.text('Vídeo'));
    await tester.pumpAndSettle();
    expect(find.text('Resolução e FPS'), findsOneWidget);
    await tester.tap(find.text('480p'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 FPS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // Lanterna abre um modal, não envia um comando automaticamente.
    await tester.tap(find.text('Lanterna'));
    await tester.pumpAndSettle();
    expect(find.text('Lanterna do transmissor'), findsOneWidget);
    await tester.tap(find.text('Ligar por 30 segundos'));
    await tester.pumpAndSettle();
    expect(commands, [
      'record/start', 'zoom/50', 'zoom/0', 'quality/480', 'fps/10', 'torch/30',
    ]);
    expect(find.text('Atualizar'), findsNothing);
    expect(find.text('FPS medido: 12'), findsNothing);
    expect(find.text('Gravação desligada'), findsNothing);
    expect(find.text('Codec'), findsNothing);
  });

  testWidgets('transmissão pausada mostra somente Iniciar, sem aviso repetido', (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: McrpControlPanel(
      status: const {'x-transmitting': '0', 'x-recording': '0'},
      working: false,
      onCommand: (action) async { commands.add(action); },
    ))));
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.textContaining('Transmissão pausada'), findsNothing);
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(commands, ['transmission/start']);
  });

  testWidgets('REC ativo preserva o controle de parada', (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: McrpControlPanel(
      status: const {'x-transmitting': '1', 'x-recording': '1'},
      working: false,
      onCommand: (action) async { commands.add(action); },
    ))));
    expect(find.text('Gravando no transmissor'), findsNothing);
    await tester.tap(find.text('Parar REC'));
    await tester.pump();
    expect(commands, ['record/stop']);
  });

  testWidgets('lanterna e zoom sem suporte ficam desabilitados', (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: McrpControlPanel(
      status: const {'x-transmitting': '1', 'x-recording': '0',
        'x-torch-supported': '0', 'x-zoom-supported': '0'},
      working: false,
      onCommand: (action) async { commands.add(action); },
    ))));
    final zoomButton = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('Zoom'), matching: find.byType(OutlinedButton)).first);
    expect(zoomButton.onPressed, isNull);
    final torchButton = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('Lanterna'), matching: find.byType(OutlinedButton)).first);
    expect(torchButton.onPressed, isNull);
    expect(commands, isEmpty);
  });
}
