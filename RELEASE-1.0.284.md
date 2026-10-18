# Vigia IA 1.0.284+284

- Nova área Planejamento na Home para cicloviagens com origem/destino selecionáveis, sem exigir localização atual.
- Busca de cidades em cache sem internet e pesquisa remota apenas ao confirmar; rotas alternativas pela infraestrutura de mapas existente.
- Velocidade, jornada diária, horário de partida e pausas configuráveis; dias e pernoites aproximados, com apoio de cidades/pontos conhecidos quando disponíveis.
- Biblioteca de viagens salva com dados suficientes para consulta da rota sem rede, até 40 planejamentos; preview sem mapa-base offline e tiles online opcionais.
- Abertura de rota no mapa atual via função Rota salva, preservando a biblioteca.
- Corrigida verificação preventiva desatualizada do tema inicial Sistema após erro no GitHub Actions build 237.
- Mantidas compatibilidade MCRP, câmeras, IA, preferências, downloads de mapas e demais funcionalidades anteriores.

**Observações:** planejamento online depende do servidor; um mapa MBTiles não contém grafo para recalcular trajeto offline. Testar `flutter analyze`, `flutter test`, build Android e fluxos físicos pelo CI/aparelho.
