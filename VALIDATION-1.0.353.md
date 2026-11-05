# Validação — Vigia IA 1.0.353+353

**Origem:** pacote local 1.0.352, verificado como mais recente; Drive tinha a 1.0.350. Falha APK #300 ocorrida em `tool/verify_project.sh`, antes de `flutter analyze`.

## Correção

- Removidas exigências estáticas de `1.0.351` do verificador integral (versão, metadados, user agents).
- Atualizados testes que fixavam 1.0.352 apesar de versões posteriores.
- Novo teste preventivo de versão para impedir números literais na verificação de release.

## Resultados verificados em 05/11/2026

- Falha APK #300 reproduzida no log: `tool/verify_project.sh` exigia `version: 1.0.351+351` apesar de o `pubspec.yaml` registrar 1.0.352+352. Workflow parou antes de `flutter analyze`.
- Os **10 guardas** dependentes da versão foram conferidos diretamente com 1.0.353 e passaram.
- **46 testes Python direcionados** de APIs, RTSP, mapa offline, verificador de release e versionamento: **46 aprovados**.
- `python3 tool/check_version_sync.py`, `python3 tool/check_release_consistency.py`, `python3 tool/check_latest_baseline.py` e `python3 tool/check_import_targets.py`: aprovados.
- `bash -n tool/verify_project.sh`: aprovado.
- `tool/verify_project.sh`: execução longa, não concluiu dentro do limite de tempo (~100 s); nenhuma falha registrada no trecho concluído. Não afirmar sucesso integral.
- Suíte Python agregada: não terminou no limite do ambiente; não afirmar aprovação integral.
- SDK Flutter/Dart não está instalado localmente: `flutter analyze`, `flutter test` e build Android **não executados**; pendentes no próximo workflow.
- Comparação com ZIP de origem: **1.304 arquivos preservados**, 0 excluídos. Três arquivos adicionados (notas, validação e teste de guard).
- ZIP final validado por CRC após empacotamento.

