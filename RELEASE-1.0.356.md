# Vigia IA 1.0.356+356 — Correção Flutter Analyze APK 303

## Falha confirmada

O workflow Android APK 303 concluiu os testes preventivos (494 testes Python, saída OK) e falhou em `flutter analyze --fatal-infos --fatal-warnings` com dois diagnósticos `curly_braces_in_flow_control_structures`, no arquivo `lib/screens/trip_planning_screen.dart` linhas 983 e 1031 da versão 1.0.355. Não chegou a compilar o APK.

## Correção aplicada

- Condição de retorno antecipado de `_openPreviewMap`: agora o `return` está dentro de `{ }`.
- Contador de amostras de cobertura de `_previewCoverageMessage`: `matches++` agora está dentro de `{ }`.
- As expressões e o fluxo de controle foram preservados.
- Teste `tool/test_build303_flutter_analyze_356.py` cobre ambos os pontos.
- Mapas MBTiles e POIs offline, introduzidos na 1.0.354, permanecem sem alteração funcional.

## Validação necessária em CI

Executar `tool/verify_project.sh`, `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e compilação Android. Sem SDK Flutter instalado neste ambiente, a análise Dart real e geração de APK dependem do GitHub Actions.
