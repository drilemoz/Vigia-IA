# Vigia IA 1.0.372+372 — Validação do build 317

- Fonte: `Vigia-IA-Android-APK-317-logs.zip` (19 arquivos), etapa `11_Analise estatica.txt`.
- `flutter analyze --fatal-infos --fatal-warnings`: erro de lint `curly_braces_in_flow_control_structures` em `lib/screens/trip_planning_screen.dart:546:37`; exit code 1.
- Etapa `10_Verificacao preventiva.txt`: 561 testes, resultado `OK`, passou antes da análise estática.
- Alteração: `if (discard == true && mounted) { setState(...); }`, mantendo a mesma condição e ações de reset da rota.
- Regressão automatizada: `tool/test_build317_flutter_analyze_372.py`.
- `flutter analyze`, `flutter test` e build Android precisam ser executados novamente no GitHub Actions; o SDK Flutter não está disponível no ambiente local.
