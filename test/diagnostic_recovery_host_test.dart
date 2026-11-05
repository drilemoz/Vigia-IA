import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/diagnostic_recovery_host.dart';

void main() {
  // O indicador de carregamento fica animando sob o diálogo. Não aguardar
  // pumpAndSettle() enquanto o aviso estiver aberto: ele nunca ficará ocioso.
  Future<void> waitForRecoveryDialog(WidgetTester tester) async {
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Erro detectado no último uso').evaluate().isNotEmpty) {
        // Finaliza a transição do diálogo antes de tocar nos seus botões.
        await tester.pump(const Duration(milliseconds: 350));
        return;
      }
    }
    fail('O aviso de recuperação não apareceu após 20 quadros.');
  }

  Widget host({
    required List<Map<String, Object?>> pending,
    Future<String?> Function(Map<String, Object?>)? save,
    Future<bool> Function(String)? acknowledge,
  }) => MaterialApp(
    home: DiagnosticRecoveryHost(
      capture: () async => {'pendingIncidents': pending},
      exportIncident: save,
      acknowledge: acknowledge,
      child: const Scaffold(body: Text('Aplicativo pronto')),
    ),
  );
  const incident = <String, Object?>{
    'id': 'previous-session',
    'reason': 'Falha nativa',
    'session': <String, Object?>{'version': '1.0.314', 'captured': 123},
  };

  testWidgets('sem incidente libera a inicialização sem aviso', (tester) async {
    await tester.pumpWidget(host(pending: []));
    await tester.pumpAndSettle();
    expect(find.text('Aplicativo pronto'), findsOneWidget);
    expect(find.text('Exportar'), findsNothing);
  });

  testWidgets('avisa antes da inicialização; Agora não mantém incidente', (
    tester,
  ) async {
    var acknowledged = false;
    await tester.pumpWidget(
      host(
        pending: [incident],
        acknowledge: (_) async {
          acknowledged = true;
          return true;
        },
      ),
    );
    await waitForRecoveryDialog(tester);
    expect(find.text('Erro detectado no último uso'), findsOneWidget);
    expect(find.text('Aplicativo pronto'), findsNothing);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(acknowledged, isFalse);
    expect(find.text('Aplicativo pronto'), findsOneWidget);
  });

  testWidgets('falha ao salvar conserva incidente e permite tentar novamente', (
    tester,
  ) async {
    var acknowledgements = 0;
    await tester.pumpWidget(
      host(
        pending: [incident],
        save: (_) async => null,
        acknowledge: (_) async {
          acknowledgements++;
          return true;
        },
      ),
    );
    await waitForRecoveryDialog(tester);
    await tester.tap(find.text('Exportar'));
    // A falha preserva o diálogo e, portanto, a animação do carregamento.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(acknowledgements, 0);
    expect(find.textContaining('Não foi possível exportar'), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
  });

  testWidgets('exporta os dados anteriores antes de confirmar o incidente', (
    tester,
  ) async {
    final operations = <String>[];
    await tester.pumpWidget(
      host(
        pending: [incident],
        save: (data) async {
          expect(data['session'], incident['session']);
          operations.add('saved');
          return 'Downloads/report.txt';
        },
        acknowledge: (id) async {
          expect(id, incident['id']);
          operations.add('acknowledged');
          return true;
        },
      ),
    );
    await waitForRecoveryDialog(tester);
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    expect(operations, ['saved', 'acknowledged']);
    expect(find.text('Aplicativo pronto'), findsOneWidget);
  });
}
