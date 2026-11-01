# Vigia IA 1.0.328+328 — Centralização de Serviços e APIs

## Correção solicitada

- Em **Configurações > Preferências**, manter somente **Serviços e APIs** como entrada para todas as seis integrações.
- Remover os atalhos redundantes **Gemini para Mapas** e **Chave do Google Maps** da tela de Configurações.
- Trocar os dois atalhos de credenciais do painel **Provedor do mapa** por um único **Serviços e APIs**.
- Caso o usuário selecione Google Maps sem chave, a caixa de orientação abre a central, preservando o fallback para o mapa anterior.
- Na tela **Buscar com Gemini**, o aviso de chave ausente também abre a central.
- As telas internas de credenciais continuam intactas e só são acessadas por cartões na central; nenhum valor de chave é migrado/apagado.
- Geoapify, OpenRouteService e Open-Meteo preservados no mesmo lugar; uso offline e demais funções de navegação preservados.

## Compatibilidade com a outra variante 1.0.327

Também incorporadas as mudanças da variante **Mapas-Busca-Unificada-Radio-Topo**: busca de destinos unificada com fallback Gemini, folha inferior compacta, atualização do indicador de rádio e ajuste de cabeçalho. O app não perde essas mudanças ao adotar a central de APIs; a origem de ambas as variantes era 1.0.326.

## Restrições

A integração de Geoapify às buscas e do OpenRouteService às rotas continua prevista para uma etapa futura. O APK precisa de confirmação pelo GitHub Actions. O ZIP é o código-fonte, não um APK compilado.

## Versionamento

`1.0.328+328`; histórico de mudanças, README, CHANGELOG, metadados, testes e verificadores atualizados.
