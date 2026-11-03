# Vigia IA 1.0.337+337 — Navegação pt-BR e painel compacto

- Base: 1.0.336+336. Sem alterações nas chaves das APIs, câmeras, backup, protocolos ou MBTiles.
- ORS e Valhalla solicitam português, com conversão local das manobras mais comuns caso o provedor responda em inglês; texto também alimenta a voz de navegação.
- Painel compacto ao iniciar rota, com expansão por toque; modo expandido menos alto e sem blocos de pontos indisponíveis.
- Indicador de GPS desatualizado, sem manobras, progresso ou avisos de voz derivados de coordenadas antigas; rota planejada preservada.
- Rotas Google/OSM com espessura reduzida, cores explícitas e remoção do botão Navegar duplicado quando já há navegação ativa.
- Testes estruturais/Python e verificações de versão registrados em `VALIDATION-1.0.337.md`.
- Flutter analyze/test, APK e validação em dispositivo pendentes no GitHub Actions.
