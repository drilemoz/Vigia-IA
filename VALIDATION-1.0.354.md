# Validação de fonte — 1.0.354+354

- Base verificada: ZIP fornecido `Vigia-IA-20261105-202834-main.zip` contendo `pubspec.yaml` 1.0.353+353. Pasta Drive do Vigia IA consultada sem ZIP de fonte mais novo listado.
- Mudanças limitadas aos serviços de POIs, prévia do Planejamento, modal Próximos pontos e sincronização de versão/documentação.
- Verificações de regressão: `tool/test_offline_planning_354.py` e `tool/verify_project.sh` (resultados devem ser anotados após execução).
- **Não equivalem a build real:** verificações Python por inspeção de código; Flutter SDK/Android não está instalado aqui.
- Testes no aparelho: GPS indisponível, falha Overpass, seleção de pacote, MBTiles incompleto e integração SQLite ainda pendentes.
