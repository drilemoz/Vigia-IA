# Validação Vigia IA 1.0.363+363

- Base: ZIP 1.0.362+362 verificado localmente e metadados da versão 1.0.362 no Google Drive; arquivos anteriores preservados.
- Código: `lib/services/trip_offline_readiness_service.dart`; tela `lib/screens/trip_planning_screen.dart`.
- Testes locais: `python3 -m unittest tool/test_trip_offline_readiness_363.py -v`, `bash tool/verify_project.sh` e verificador de versão.
- Testes Dart para CI: `test/trip_offline_readiness_363_test.dart` (arquivo ausente, bounds múltiplos, limite desconhecido, notas inválidas, POIs próximos, cache expirado).
- Sem SDK Flutter/Dart local: `flutter analyze`, `flutter test` e build APK continuam pendentes.

## Resultado da verificação local — 06/11/2026

- `bash tool/verify_project.sh`: **aprovado**, código de saída 0 (reexecução final).
- `python3 -m unittest discover -s tool -p 'test_*.py' -v`: 533 testes executados, **532 aprovados e 1 ignorado** (sem SDK Dart).
- Novos contratos Python: 5 aprovados. O arquivo Dart de regressões contém 8 casos para execução no CI.
- `tool/check_version_sync.py`: 1.0.363+363 sincronizada.
- `flutter analyze`, `flutter test` e compilação Android: **não executados localmente** por ausência do SDK Flutter/Dart.
- A verificação de bounds e o teste de arquivo não comprovam integridade SQLite ou disponibilidade de tiles no nível de zoom necessário.
