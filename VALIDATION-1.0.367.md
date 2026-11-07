# Validação Vigia IA 1.0.367+367

Base verificada: 1.0.366+366, código-fonte local e metadado GitHub público. Referência Uai Cortes 0.1.204 lida do ZIP real em Meu Drive/Projetos/Uai Cortes.

- Testes: `python3 -m unittest -q tool/test_github_updates_367.py` e `test/github_release_update_test.dart` no Flutter CI.
- Checklist: HTTPS GitHub e Release oficial, SHA-256, assinatura instalada, tamanho/código do APK, nenhuma instalação silenciosa, falha offline não bloqueante, consulta manual e automática.
- Flutter Analyze, testes Dart e compilação APK pendentes de execução com SDK Flutter/Android.

## Resultados da execução local (07/11/2026)

- `bash tool/verify_project.sh`: **APROVADO**, código de saída 0.
- `python3 -m unittest -q tool/test_github_updates_367.py`: **5 testes aprovados**.
- `python3 tool/check_version_sync.py`, `python3 tool/check_latest_baseline.py` e `python3 tool/check_release_consistency.py`: **aprovados**.
- Testes Dart/Flutter (`test/github_release_update_test.dart`), `flutter analyze` e build APK: **pendentes do GitHub Actions**. Flutter/Dart SDK não disponível neste ambiente.
- Em dispositivo Android ainda é necessário validar a consulta à API pública do GitHub, a disponibilidade de `asset.digest`, o FileProvider, a permissão de instalação e a assinatura do APK.
