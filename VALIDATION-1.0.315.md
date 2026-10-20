# Validação — Vigia IA 1.0.315+315

- Evidência: `Vigia-IA-Android-APK-263-logs.zip`, arquivo `build/11_Analise estatica.txt`.
- Erros de análise relatados: `unnecessary_import` em `lib/services/automatic_diagnostics_service.dart:3`, `avoid_relative_lib_imports` em `tool/dart/diagnostic_redactor_test.dart:1`, `avoid_print` em `tool/dart/diagnostic_redactor_test.dart:35`.
- Teste regressivo: `tool/test_build263_flutter_analyze_315.py`, executado pela verificação preventiva.
- `tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovados. Nove testes Python direcionados foram aprovados, e `bash -n tool/verify_project.sh` passou. A execução integral de `tool/verify_project.sh` foi iniciada, mas não concluiu dentro do limite de execução local (os primeiros grupos reportaram OK); não afirmar aprovação total.
- SDK Flutter e Dart indisponíveis localmente; `flutter analyze`, `flutter test`, download do modelo e `flutter build apk`/R8 dependem de novo workflow.
- Nenhuma validação física realizada em Redmi A3 ou Redmi Note 11.
