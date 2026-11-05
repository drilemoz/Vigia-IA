# Vigia IA 1.0.343+343 — Correção do Flutter Analyzer (APK 288)

## Falha observada

O workflow Android APK 288 aprovou `tool/verify_project.sh`, mas parou em `flutter analyze --fatal-infos --fatal-warnings` com dois diagnósticos do tipo `info`: `curly_braces_in_flow_control_structures` em `map_monitoring_screen.dart:2168` e `use_null_aware_elements` em `map_monitoring_screen.dart:3028`.

## Correções

- Guarda da rota inicial salva agora tem chaves explícitas.
- Fallback da rota Bike selecionada usa `<MapCyclingRoute>[?_cyclingRoute]`, mantendo o comportamento de lista vazia se não existir rota.
- Proteções preventivas para ambos os erros e metadados/Novidades/Sobre/documentação atualizados para 1.0.343+343.

## Preservado

Planejamento e biblioteca compartilhados, fluxo de prévia/navegação, MBTiles offline, MapLibre 3D e demais módulos.

## Validação

Consultar `VALIDATION-1.0.343.md`. A versão fonte não contém APK; para confirmar os diagnósticos eliminados executar `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e assemble via GitHub Actions.
