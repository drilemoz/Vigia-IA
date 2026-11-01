# Vigia IA 1.0.328+328 — Validação da centralização

## Verificações executadas

- Contrato de regressão `tool/test_api_centralization_328.py` confere que Configurações mostra somente uma entrada para as APIs, o painel do mapa concentra os atalhos, e as seis opções continuam acessíveis pela central.
- **PASSOU**: `tool/verify_project.sh`, código de saída 0, com todos os verificadores estruturais e de segurança esperados pela versão.
- **PASSOU**: `python -m unittest discover -s tool -p "test_*.py" -q`: **377 testes**, **1 ignorado**, **0 falhas**.
- Consistência de versão: `tool/check_release_consistency.py`.
- Código-fonte e metadados sincronizados; integridade ZIP conferida durante o empacotamento.

## Limitações

`flutter analyze`, `flutter test`, build APK e verificação física no Android não foram executados: Flutter SDK indisponível neste ambiente. Os testes Python/estruturais não substituem compilação real.
