# Vigia IA 1.0.334+334 — backup de APIs e UX de mapas

1. Central de APIs: exportação e importação criptografadas de Gemini, chave Google Maps salva, Stadia Maps, Geoapify, ORS; Open-Meteo sem chave. Proteção AES-256-GCM/PBKDF2, senha de ao menos 10 caracteres, seleção SAF, pré-visualização e confirmação de substituição. Não exporta a chave Google Maps incorporada ao APK.
2. Pesquisas: carregamento de cidades e POIs limitado por tempo; nomes diretos pesquisados no OSM sem ida prévia à IA; Nominatim com timeout de corpo; estado de carregamento não herdado de consulta anterior.
3. Mapa: sem barra extra "Mapas", linha principal unificada Vigia IA/Explorar/Perto/Região/Rota/Camadas, remoção de item duplicado de modo do menu.
4. Preservados: câmeras/MCRP/RTSP, IA local, MBTiles/OSM offline, rádio, Stadia, APIs e navegação. Google Maps SDK não oferece downloads offline de tiles licenciados para o app.

Verificar no aparelho Android: exportação e importação com senha correta/incorreta, backup em outro aparelho, estados sem chave, fluxos de erro, teclado, largura de telas e consultas com/sem internet. Flutter analyze/test e montagem APK pendentes caso SDK indisponível.

## Auditoria visual e de menus (somente observações)

- Tela de pesquisa: a digitação consulta primeiro dados locais; a pesquisa OSM é iniciada pelo botão de confirmação. O aviso de "nenhuma sugestão local" antes de tocar em buscar NÃO significa falha da busca online.
- A busca de pontos próximos está ancorada na localização do aparelho, não na cidade/pino selecionado ao mover o mapa. Com GPS antigo ou mapa deslocado, os resultados podem parecer vazios. Sugestão posterior: opção **Buscar nesta área** com centro da câmera do mapa e indicação clara da origem (não implementada nesta etapa).
- Ações que já estão fora do menu: buscar, camadas, controles de mapa, áudio rápido, GPS, zoom, gravação. Ações candidatas a atalhos configuráveis: rádio, mapas offline, bike/sensores e pontos próximos; preferir no máximo duas para não cobrir o mapa.
- `Mapas offline` e `Alertas de velocidade` são acessíveis por mais de um caminho (camadas/opções/configurações), mas representam a mesma função e não criam dados duplicados. O item `Modo do mapa` foi removido do menu após receber atalho direto na barra principal.
- Contador de créditos Stadia é limite **local** configurável, não saldo ou cota validada pelo provedor. Google Maps SDK não fornece licença para exportação offline em MBTiles.
- Outras telas não foram redesenhadas.
