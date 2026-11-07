# Validação Vigia IA 1.0.362+362

- Fonte: ZIP local 1.0.361+361 e metadados do mesmo arquivo no Google Drive, conferidos em 06/11/2026. Nenhuma entrada da base pode ser eliminada.
- Modelo e UI: `lib/models/trip_stop_check.dart`, `lib/models/planned_bike_trip.dart`, `lib/screens/trip_planning_screen.dart`.
- Contratos Python: `tool/test_trip_stop_check_362.py` e `tool/verify_project.sh`.
- Testes Dart: `test/trip_stop_check_362_test.dart` (JSON retrocompatível, corrupção isolada, notas limitadas, validação da posição da parada e do índice de rota).
- Sem SDK Flutter/Dart local: `flutter analyze`, `flutter test` e compilação APK requerem GitHub Actions. A disponibilidade real dos serviços não é determinada automaticamente.

## Resultado local da validação

- `bash tool/verify_project.sh`: **aprovado**, código de saída 0, após a integração final do checklist.
- Suíte Python do projeto: **528 testes executados, 527 aprovados e 1 ignorado** (necessidade do SDK Dart para a verificação correspondente).
- `tool/test_trip_stop_check_362.py`: **6 testes de contrato aprovados**.
- `tool/check_release_consistency.py` e `tool/check_version_sync.py`: **aprovados**, versão `1.0.362+362`.
- `flutter analyze`, `flutter test` e APK Android: não executados localmente, **pendentes do CI**.
