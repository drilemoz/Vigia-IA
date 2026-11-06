# Vigia IA 1.0.355+355 — Correção workflow Android APK 302

## Diagnóstico confirmado nos logs recebidos

- Workflow Android APK 302: falha na etapa `10_Verificacao preventiva`, antes de executar análise Dart ou compilação do APK.
- O teste `tool/test_trip_planning_wizard_285.py`, linha 40 no commit executado, exigia `_routeMap(route)`; o widget atualmente usa `_routeMap(trip)`.
- Não há evidência nos logs de falha de compilação Flutter, Gradle ou R8; essas etapas não chegaram a executar.

## Correção

- O contrato usa agora a assinatura de `_preview(PlannedBikeTrip ...)` para identificar o nome real de seu parâmetro e verificar as chamadas do mapa e das ações.
- Regressão adicionada para prevenir o retorno de comparação textual com `_routeMap(route)`.
- Funcionalidades offline (MBTiles, POIs sem GPS) de 1.0.354 mantidas integralmente.

## Testar no CI

- Enviar a versão 1.0.355+355 ao repositório e executar o workflow novamente.
- Confirmar `tool/verify_project.sh`, `flutter analyze`, `flutter test` e build completo do APK; o log 302 não comprova essas etapas.
