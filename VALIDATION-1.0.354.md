# Validação de fonte — 1.0.354+354

- Base verificada: ZIP fornecido `Vigia-IA-20261105-202834-main.zip` contendo `pubspec.yaml` 1.0.353+353. Pasta Drive do Vigia IA consultada sem ZIP de fonte mais novo listado.
- Mudanças limitadas aos serviços de POIs, prévia do Planejamento, modal Próximos pontos e sincronização de versão/documentação.
- Verificações de regressão: `tool/test_offline_planning_354.py` aprovado; `tool/verify_project.sh` concluído com saída 0 em 05/11/2026. A suíte estrutural executou 491 testes Python, com 4 ignorados nessa execução.
- **Não equivalem a build real:** verificações Python por inspeção de código; Flutter SDK/Android não está instalado aqui.
- Testes no aparelho: GPS indisponível, falha Overpass, seleção de pacote, MBTiles incompleto e integração SQLite ainda pendentes.
