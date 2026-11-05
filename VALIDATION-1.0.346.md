# Validação 1.0.346+346

- Fonte corrigida após falha no `flutter test` do workflow APK 291: 3 casos de `diagnostic_recovery_host_test.dart` usavam texto da interface pré-1.0.345.
- Teste de versão atual adicionado.
- `bash tool/verify_project.sh`: **aprovado, código de saída 0**.
- Suíte consolidada Python: **456 testes**, **1 ignorado**, **0 falhas**.
- Checagens de versão `tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovadas.
- Integridade do ZIP: verificada após o empacotamento.
- `flutter analyze` e `flutter test` reais dependem do SDK Flutter.
