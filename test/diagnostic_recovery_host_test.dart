import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/diagnostic_recovery_host.dart';

void main() {
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    expect(operations, ['saved', 'acknowledged']);
    expect(find.text('Aplicativo pronto'), findsOneWidget);
  });
}
