# Vigia IA 1.0.285+285

- A tela Planejamento inicia limpa: ação Nova rota e biblioteca local de viagens existentes.
- Novo assistente modal (wizard) com origem, destino e ritmo da pedalada; cidades online somente por busca explícita.
- Opção Meu local na origem pede permissão somente ao toque e usa a coordenada atual, sem iniciar rastreamento contínuo.
- Após avançar, o app calcula alternativas existentes por Valhalla e abre a prévia no próprio Planejamento com mapa e dias estimados.
- Ações próximas do mapa: Salvar, Apagar (confirmação) e Exportar (GPX de traçado ou JSON integral pelo seletor Android).
- Biblioteca anterior JSON schema 1, mapas, cache, modelos, transmissor Kotlin/MCRP e tema do sistema preservados.
- Rotas previamente baixadas seguem disponíveis offline; recalcular sem rede ainda não existe.

**Validação:** testes Python, contratos e integridade ZIP; análise Flutter, teste Flutter e build Android dependem do GitHub Actions.
