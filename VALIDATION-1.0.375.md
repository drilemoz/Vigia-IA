# Validação 1.0.375+375

Base confirmada: fonte 1.0.374+374 no ZIP local e único ZIP na pasta Meu Drive/Projetos/Vigia IA em 09/11/2026.

Cobertura específica: `tool/test_trip_planner_safety_375.py` (contratos estáticos), `test/trip_planner_safety_375_test.dart` (testes de cálculo Dart previstos para CI), e testes existentes de metas, interface e versionamento.

Os testes Python preventivos não substituem `flutter analyze`, `flutter test`, compilação Android ou verificação física do mapa/GPS.

Resultados da rodada local: `python3 -m unittest discover -s tool -p 'test_*.py' -q` executou 575 testes, sendo 574 aprovados, 1 pulado e 0 falhas. `bash tool/verify_project.sh` terminou com código 0. `tool/check_version_sync.py`, `tool/check_latest_baseline.py` e `tool/check_release_consistency.py` aprovados. Integridade ZIP verificada após empacotamento. O SDK Flutter/Android não está instalado neste ambiente; testes Dart, análise Flutter e compilação aguardam GitHub Actions.
