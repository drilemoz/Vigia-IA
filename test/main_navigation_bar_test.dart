import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/main_navigation_bar.dart';

void main() {
  testWidgets('menu principal mantém seis destinos e abre Ajustes no topo', (tester) async {
    int? selectedIndex;
    // Mimics the fast native recorder response. Without an Android messenger,
    // AutomaticDiagnosticsService leaves Future.timeout's FakeAsync timers
    // pending when the widget test ends, despite navigation working normally.
    const nativeChannel = MethodChannel('vigiaia/native');
    final nativeEvents = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      nativeEvents.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(nativeChannel, null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainNavigationBar(
            currentIndex: 0,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(6));
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Câmeras'), findsOneWidget);
    expect(find.text('Galeria'), findsOneWidget);
    expect(find.text('Mapas'), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing);
    expect(find.text('Bike'), findsNothing);

    await tester.tap(find.text('Câmeras'));
    await tester.pump();

    expect(selectedIndex, 3);

    await tester.tap(find.text('Galeria'));
    await tester.pump();
    expect(selectedIndex, 4);

    await tester.tap(find.text('Mapas'));
    await tester.pump();
    expect(selectedIndex, 5);

    // The diagnostic trail survives and captures actual menu choices.
    // No 3-second diagnostic transport timers should survive test teardown.
    await tester.pumpAndSettle();
    final details = nativeEvents
        .where((call) => call.method == 'diagnosticEvent')
        .map((call) => (call.arguments as Map)['detail'].toString())
        .toList();
    expect(details, hasLength(3));
    expect(details[0], contains('acao=aba_Câmeras'));
    expect(details[1], contains('acao=aba_Galeria'));
    expect(details[2], contains('acao=aba_Mapas'));
    expect(details.every((detail) => detail.contains('area=navegacao')), isTrue);
  });
}
