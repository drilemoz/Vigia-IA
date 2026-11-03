# Validação — Vigia IA 1.0.332+332 (APK 278)

## Evidências do workflow APK 278
- `tool/verify_project.sh`: sucesso na execução do GitHub Actions sobre a versão 1.0.331.
- Suíte preventiva: 385 testes Python concluídos (OK); MCRP 245: 22 contratos aprovados.
- `flutter analyze`: falhou somente com `curly_braces_in_flow_control_structures` em `lib/sources/rtsp_camera_source.dart:281`.

## Correção e validação local
- `if (...) return;` transformado em `if (...) { return; }` sem mudanças lógicas.
- Acrescentado `tool/test_build278_rtsp_lint_332.py` e atualizado `tool/verify_project.sh` para executar o teste preventivo.
- `python3 -m unittest discover -s tool -p "test_*.py" -q`: **387 testes, 386 aprovados e 1 ignorado (exit 0)**.
- `bash tool/verify_project.sh`: **aprovado (exit 0)**, incluindo os contratos adicionais antigos e o teste novo do lint.
- `python3 tool/check_version_sync.py`, `python3 tool/check_release_consistency.py` e `python3 tool/check_news_catalog_policy.py`: aprovados.
- `bash -n tool/verify_project.sh`: aprovado.
- Integridade ZIP: verificada após empacotamento.

## Limitações
- Flutter SDK ausente neste ambiente. `flutter analyze`, `flutter test`, build Android e testes físicos não foram executados localmente.
