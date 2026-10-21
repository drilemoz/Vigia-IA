# Validação Vigia IA 1.0.319+319

## Executada

- Regressões estruturais: `tool/test_ui_diagnostics_319.py`.
- Metadados/versionamento: `tool/check_version_sync.py`, `tool/check_release_consistency.py`.
- Suíte geral: `python3 -m unittest discover -s tool -p 'test_*.py'`: **333 testes, 329 aprovados, 4 ignorados** com Kotlin/Dart fora do PATH.
- Verificador completo: `bash tool/verify_project.sh`: **aprovado** com Kotlin/Dart indisponíveis.
- Incluído teste widget Flutter em `test/diagnostic_ui_interaction_capture_test.dart`, ainda não executado localmente.
- Código Android e modelos do bootstrap idênticos; verificador `tool/test_ui_diagnostics_319.py`: 6 testes aprovados.

## Pendente

- Flutter SDK não disponível localmente: `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e `flutter build apk` dependem do GitHub Actions.
- Persistência e carga I/O de toques, eventos após travamento real e privacidade devem ser verificadas em aparelhos físicos.
