# Validação — Vigia IA 1.0.344+344

## Evidência do workflow APK 289

- `bash tool/verify_project.sh`: passou no GitHub Actions.
- `flutter analyze --fatal-infos --fatal-warnings`: **No issues found!**.
- `flutter test`: 619 testes aprovados, 1 falha em `test/map_route_preview_card_test.dart:76` ao procurar "Carregando plano", ausente na prévia sem plano.

## Mudanças

- Ajustado teste Flutter para `Planejar viagem` antes do plano e `Plano 2d` após existir a estimativa.
- Simulação de `onPlan` segue o contrato da tela Mapas: rota pronta, bicicleta e não carregando, independentemente do plano pré-calculado.
- Cobertura de callback `plano` e pré-verificação Python para evitar o falso negativo do APK 289.

## Verificações locais

- `python3 -m unittest -q tool/test_build289_preview_card_344.py`: **3/3 aprovados**.
- `python3 -m unittest discover -s tool -p 'test_*.py' -q`: **449 executados (448 aprovados, 1 ignorado, 0 falhas)**.
- `bash tool/verify_project.sh`: **aprovado, exit 0**; inclui novos contratos e verificações antigas.
- `python3 tool/check_version_sync.py`: aprovado para **1.0.344+344**.
- `python3 tool/check_release_consistency.py`: aprovado para **1.0.344+344**.
- `python3 tool/check_news_catalog_policy.py`: **3 mensagens válidas** na única release atual.
- `bash -n tool/verify_project.sh` e `python3 -m compileall -q tool`: aprovados.
- Integridade do ZIP: CRC e arquivos obrigatórios verificados após empacotamento.

## Limites

Sem Flutter/Dart SDK local não é possível executar `flutter analyze`, `flutter test` e `assemble`. A aprovação no APK 289 vale para a versão anterior, não comprova a compilação Android da 1.0.344.
