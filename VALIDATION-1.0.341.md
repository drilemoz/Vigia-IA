# Validação — Vigia IA 1.0.341+341

## Escopo

Unificação da tela Planejamento e do plano Bike em Mapas; biblioteca offline compartilhada, migração conservadora de última rota, preferências persistidas e testes de regressão, preservando navegação e MBTiles.

## Execução

- Testes direcionados: **32 aprovados, 0 falhas**, executando `test_unified_bike_planning_341.py` e contratos de Planejamento 284/285, edição de ritmo ativo 323, política de Novidades 301, release 296 e ciclo MBTiles/MapLibre 339.
- `tool/verify_project.sh`: **executado parcialmente; excedeu o limite de 200 s**. As etapas que concluíram no registro estavam aprovadas, mas o script não chegou ao fim (interrompido antes da finalização dos testes de exportação YOLO). A suíte completa **não** está aprovada neste ambiente.
- `tool/check_release_consistency.py`, `tool/check_news_catalog_policy.py` e `bash -n tool/verify_project.sh`: aprovados.
- `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` (incluindo `bike_trip_unified_flow_test.dart`), build Android e teste em aparelho: pendentes (SDK indisponível no ambiente de geração).
- Teste manual recomendado: abrir rota de Mapas, Plano, alterar ritmo, salvar, voltar e conferir biblioteca; abrir Plano da tela inicial, consultar offline, exportar, abrir prévia diretamente em Mapas, testar navegação; instalar sobre a versão anterior sem perder viagens.

**Atenção:** validar resultados reais antes de considerar regressões de Android/GPS/PlatformView resolvidas.
