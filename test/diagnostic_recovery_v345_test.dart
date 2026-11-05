import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/diagnostic_recovery_host.dart';

void main() {
  Future<void> waitForTitle(WidgetTester tester, String title) async {
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text(title).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 350));
        return;
      }
    }
    fail('Diálogo de diagnóstico não apareceu: $title');
  }

  testWidgets('encerramento de memória em cache é informação, não erro', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: DiagnosticRecoveryHost(
        capture: () async => {
          'pendingIncidents': [
            {
              'id': 'old-memory',
              'severity': 'info',
              'sourceVersion': '1.0.340',
              'reason': 'Android encerrou o processo em segundo plano por pressão de memória',
            },
          ],
        },
        child: const Scaffold(body: Text('Início')),
      ),
    ));
    await waitForTitle(tester, 'Encerramento anterior do Android');
    expect(find.textContaining('Registro da versão 1.0.340'), findsOneWidget);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);
  });

  testWidgets('registro legado de memória em cache também aparece como informação', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: DiagnosticRecoveryHost(
        capture: () async => {
          'pendingIncidents': [
            {
              'id': 'legacy-memory',
              'reason': 'Android encerrou o processo por falta de memória',
              'lastExit': {'reason': 3, 'importance': 400},
              'session': {'version': '1.0.340'},
            },
          ],
        },
        child: const Scaffold(body: Text('Início')),
      ),
    ));
    await waitForTitle(tester, 'Encerramento anterior do Android');
    expect(find.textContaining('Registro da versão 1.0.340'), findsOneWidget);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
  });

  testWidgets('falha de versão anterior não é rotulada como falha da atual', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: DiagnosticRecoveryHost(
        capture: () async => {
          'pendingIncidents': [
            {'id': 'past', 'severity': 'error', 'sourceVersion': '1.0.339', 'reason': 'Falha nativa'},
          ],
        },
        child: const Scaffold(body: Text('Início')),
      ),
    ));
    await waitForTitle(tester, 'Falha recuperada de versão anterior');
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
  });

  testWidgets('falha temporária ao consultar nativo é reavaliada no resume', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: DiagnosticRecoveryHost(
        capture: () async {
          attempts++;
          if (attempts == 1) return {'available': false};
          return {
            'pendingIncidents': [
              {'id': 'recovered', 'severity': 'error', 'reason': 'Aplicativo não respondeu (ANR)'},
            ],
          };
        },
        child: const Scaffold(body: Text('Início')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitForTitle(tester, 'Erro detectado no último uso');
    expect(attempts, 2);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Erro detectado no último uso'), findsNothing);
  });
}
