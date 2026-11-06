# Vigia IA 1.0.358+358 — Buildfix APK 305

O workflow Android 305 executou os testes preventivos (504 testes Python, OK) e falhou em `flutter analyze --fatal-infos --fatal-warnings` com **um aviso fatal** (`curly_braces_in_flow_control_structures`) em `lib/services/map_destination_search_service.dart:613`. O APK não foi compilado.

O filtro de pontos OSM com coordenadas ausentes/não finitas/fora do intervalo possui agora um bloco explícito `{ continue; }`. Lógica de exclusão intacta. Adicionado teste estrutural de regressão `tool/test_build305_flutter_analyze_358.py`. Itinerário offline, POIs, cache MBTiles, câmeras e demais módulos mantidos.

**Validação necessária**: rodar `tool/verify_project.sh`, `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e workflow Android. Teste estrutural local não substitui compilação.
