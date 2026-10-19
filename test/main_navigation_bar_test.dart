import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/widgets/main_navigation_bar.dart';

void main() {
  testWidgets('menu principal mantém seis destinos e abre Ajustes no topo', (tester) async {
    int? selectedIndex;

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
  });
}
