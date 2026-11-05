import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_view_settings_service.dart';
import 'package:vigiaia/widgets/map_layer_picker_panel.dart';

const initial = MapLayerPickerSelection(
  appearancePreset: MapAppearancePreset.standard,
  appearanceMode: MapAppearanceMode.manual,
  provider: MapProvider.current,
  stylePreset: MapStylePreset.standard,
);

Future<void> showPicker(
  WidgetTester tester, {
  bool hasStadia = true,
  bool hasGoogleSdk = false,
  bool googleOnline = true,
  required ValueChanged<MapLayerPickerSelection> onConfirm,
  required VoidCallback onCancel,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 430,
          height: 600,
          child: MapLayerPickerPanel(
            initial: initial,
            googleSdkConfigured: hasGoogleSdk,
            googleOnlineAvailable: googleOnline,
            stadiaConfigured: hasStadia,
            onConfirm: onConfirm,
            onCancel: onCancel,
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('modo manual e automático, base e provedor são escolhas locais até OK',
      (tester) async {
    MapLayerPickerSelection? saved;
    await showPicker(tester, onConfirm: (value) => saved = value, onCancel: () {});

    expect(find.byKey(const ValueKey('layer-choice-appearance-standard')), findsOneWidget);
    expect(find.byKey(const ValueKey('layer-choice-appearance-dark')), findsOneWidget);
    expect(find.byKey(const ValueKey('layer-choice-appearance-highContrast')), findsOneWidget);
    expect(find.byKey(const ValueKey('layer-choice-appearance-bikeTravel')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('layer-choice-appearance-day-night')));
    await tester.tap(find.byKey(const ValueKey('layer-choice-appearance-day-night')));
    await tester.pumpAndSettle();
    expect(find.text('Selecionado: Dia/noite'), findsOneWidget);
    expect(saved, isNull);

    await tester.tap(find.byKey(const ValueKey('layer-tab-base')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('layer-choice-base-satellite')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('layer-choice-base-topographic')));
    await tester.pumpAndSettle();
    expect(find.text('Selecionado: Topográfico'), findsOneWidget);
    expect(saved, isNull);

    await tester.tap(find.byKey(const ValueKey('layer-apply-button')));
    expect(saved, isNotNull);
    expect(saved!.appearanceMode, MapAppearanceMode.dayNight);
    expect(saved!.stylePreset, MapStylePreset.topographic);
  });

  testWidgets('bloqueios de API são informados sem atalhos de configuração',
      (tester) async {
    MapLayerPickerSelection? saved;
    var cancelled = false;
    await showPicker(
      tester,
      hasStadia: false,
      onConfirm: (value) => saved = value,
      onCancel: () => cancelled = true,
    );
    await tester.tap(find.byKey(const ValueKey('layer-tab-provider')));
    await tester.pumpAndSettle();
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.textContaining('exige chave Google Maps incorporada'), findsOneWidget);
    expect(find.text('Serviços e APIs'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('layer-tab-base')));
    await tester.pumpAndSettle();
    expect(find.text('Terreno'), findsOneWidget);
    expect(find.text('Satélite'), findsOneWidget);
    expect(find.textContaining('Exige chave Stadia Maps'), findsNWidgets(2));
    await tester.tap(find.text('Cancelar'));
    expect(cancelled, isTrue);
    expect(saved, isNull);
  });

  testWidgets('Google habilitado permite base satélite sem Stadia', (tester) async {
    MapLayerPickerSelection? saved;
    await showPicker(
      tester,
      hasGoogleSdk: true,
      hasStadia: false,
      onConfirm: (value) => saved = value,
      onCancel: () {},
    );
    await tester.tap(find.byKey(const ValueKey('layer-tab-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('layer-choice-provider-google')));
    await tester.tap(find.byKey(const ValueKey('layer-tab-base')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('layer-choice-base-satellite')));
    await tester.tap(find.byKey(const ValueKey('layer-choice-base-satellite')));
    await tester.tap(find.byKey(const ValueKey('layer-apply-button')));
    expect(saved?.provider, MapProvider.google);
    expect(saved?.stylePreset, MapStylePreset.satellite);
  });
  testWidgets('Google selecionado sem conexão não libera bases dependentes de Stadia',
      (tester) async {
    MapLayerPickerSelection? saved;
    await showPicker(
      tester,
      hasGoogleSdk: true,
      googleOnline: false,
      hasStadia: false,
      onConfirm: (value) => saved = value,
      onCancel: () {},
    );
    await tester.tap(find.byKey(const ValueKey('layer-tab-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('layer-choice-provider-google')));
    await tester.tap(find.byKey(const ValueKey('layer-tab-base')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Exige chave Stadia Maps'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('layer-apply-button')));
    expect(saved?.provider, MapProvider.google);
    expect(saved?.stylePreset, MapStylePreset.standard);
  });

}
