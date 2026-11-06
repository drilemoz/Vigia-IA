# Vigia IA 1.0.354+354 — pacote fonte

## Implementado
- Abrir pacotes de pontos armazenados sem GPS, incluindo marcadores. O valor de distância é ocultado até existir GPS ou referência manual.
- Consultas manuais no mapa recuperam dados offline após erros de transporte/Overpass; a lógica de seleção deixa de reutilizar pontos de outra área.
- Planejamento pode abrir MBTiles raster local e escolher outro pacote. Mostra avisos conservadores sobre os limites declarados, e ícones dos pontos salvos próximos à geometria.
- Atalho para pacotes offline na lista de pontos próximos.

## Limitações
- O pacote MBTiles pode cobrir apenas parte da rota e limites geográficos não comprovam tiles para todas as escalas.
- POIs não constituem grafo de rotas; proximidade não confirma passagem ou acesso seguro.
- O limite de 100 MiB do cache direto Stadia Maps não foi removido.
- Altimetria por etapa, cidades automáticas e meteorologia por dia são etapas seguintes, não entregues nesta versão.
- SDK Flutter/Android não disponível no ambiente de preparação; CI e teste no aparelho obrigatórios antes da instalação sobre uso crítico.

## Recomendação de teste Android
1. Em Mapas, abrir um pacote de POIs salvo sem GPS e sem internet; confirmar lista e marcadores sem distância.
2. Em local escolhido manualmente, simular falha da rede e verificar retorno dos pontos locais do raio.
3. Abrir uma viagem salva, selecionar MBTiles, conferir trechos com base, marcadores e aviso de cobertura.
4. Trocar pacotes e entrar/sair da tela repetidamente, conferindo se o SQLite não fecha durante leitura de tiles.
5. Validar Flutter Analyze, Flutter Test e geração de APK no GitHub Actions.
