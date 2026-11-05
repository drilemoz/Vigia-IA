# Validação — Vigia IA 1.0.343+343

## Origem e correção

O workflow APK 288 concluiu `bash tool/verify_project.sh` com sucesso e falhou em `flutter analyze --fatal-infos --fatal-warnings`. Ocorreram dois diagnósticos informativos, elevados a fatais pela configuração do CI, em `lib/screens/map_monitoring_screen.dart`:

- Linha 2168 do fonte 1.0.342: `curly_braces_in_flow_control_structures` — guard de rota salva inicial sem bloco.
- Linha 3028 do fonte 1.0.342: `use_null_aware_elements` — elemento opcional no fallback de lista Bike.

O guard agora usa `if (...) { return; }`. O fallback utiliza `<MapCyclingRoute>[?_cyclingRoute]`. Não houve mudança intencional no comportamento de roteamento ou persistência.

## Verificações e resultados

- `python3 -m unittest -v tool/test_build288_flutter_analyze_343.py`: **3/3 aprovados**.
- `bash tool/verify_project.sh`: **aprovado, exit 0**.
- Suíte integrada `python3 -m unittest discover -s tool -p 'test_*.py' -v` executada pelo verificador: **446 testes; 445 aprovados e 1 ignorado; 0 falhas**.
- `python3 tool/check_version_sync.py`: **aprovado**, versão **1.0.343+343**.
- `python3 tool/check_release_consistency.py`: **aprovado**.
- `python3 tool/check_news_catalog_policy.py`: **aprovado**, três mensagens válidas.
- `bash -n tool/verify_project.sh`, AST dos 149 scripts Python, 2 JSON e 5 scripts Shell: **aprovados**.
- ZIP: integridade CRC e versão nos arquivos principais verificadas no empacotamento.

## Limites

A validação estrutural local não substitui a execução de `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, build Android e testes no aparelho, que permanecem pendentes até o próximo workflow. Não foi possível executar Dart/Flutter localmente.
