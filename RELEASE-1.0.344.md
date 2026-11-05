# Vigia IA 1.0.344+344 — correção do teste Flutter APK 289

## Problema confirmado

O workflow APK 289 aprovou a verificação preventiva e `flutter analyze`, mas falhou em `flutter test` ao esperar o texto antigo "Carregando plano" em uma prévia de rota Bike sem um plano calculado. O widget atual exibe "Planejar viagem" até que os dias estejam calculados.

## Correção

- `test/map_route_preview_card_test.dart`: corrigido o texto esperado para o estado sem plano e a simulação da ação `onPlan` para refletir a tela Mapas.
- Novos testes de widget verificam o botão habilitado mesmo sem plano e o rótulo `Plano 2d` quando o cálculo existe.
- `tool/test_build289_preview_card_344.py` garante que o teste Flutter não retorne a uma expectativa legada sem ser detectado antes da etapa Flutter.
- Versão, catálogo de Novidades, tela Sobre (dois históricos), README, CHANGELOG, arquitetura e contrato de release sincronizados.

## Preservação

Nenhuma alteração intencional em `MapRoutePreviewCard` ou na lógica de roteamento, mapas offline, transmissão de câmeras e IA. O erro evidenciado pelos logs é exclusivamente do teste.

## Validação

Consultar `VALIDATION-1.0.344.md`. O projeto não inclui APK; verificar `flutter analyze`, `flutter test` e o build Android no próximo workflow.
