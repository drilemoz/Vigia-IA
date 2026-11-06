# Validação 1.0.357+357

- Base: ZIP 1.0.356+356 confirmado por `pubspec.yaml` e metadados do Google Drive.
- Regressões incluídas: `tool/test_route_itinerary_357.py` e `test/route_corridor_index_test.dart`.
- Propriedades verificáveis: geometria em ordem do trajeto, distância ao traçado, exclusão de localidades distantes, limite de amostras por distância, consulta online somente manual, fallback local, pacotes POI no mapa e compatibilidade com a biblioteca anterior.
- `tool/verify_project.sh` **aprovado**, código de saída 0 em 05/11/2026; suíte Python principal: **504 testes**, com **1 ignorado**, além dos verificadores complementares de Kotlin/JVM, release e contratos de interface.
- Testes direcionados do itinerário e regressões offline: **27 aprovados**.
- Sem SDK Flutter/Dart local: `flutter analyze`, `flutter test` e compilação Android **não executados**; os testes Python são estruturais e não substituem compilação.
