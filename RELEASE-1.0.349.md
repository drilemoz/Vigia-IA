# Vigia IA 1.0.349+349 — economia de energia e refatoração incremental

## Alterações
- Pausa do temporizador do HUD do mapa ao ocultar a aba ou ao enviar o aplicativo ao segundo plano; retomada sem timers duplicados.
- Bússola Android suspensa quando a tela não está ativa e retomada somente ao exibir o mapa.
- Evita reconstrução de UI para bateria e rádio que não mudaram; tolera falha temporária da leitura opcional de bateria.
- Extração de `MapHudRefreshPolicy` e `MapCameraSourcePolicy` para facilitar testes e manutenção da tela de mapas.
- Rota ativa, GPS de navegação/gravação, PiPs de câmera e armazenamento offline mantidos; sem novo motor de roteamento offline.

## Validação
- Consulte `VALIDATION-1.0.349.md`. Testes Flutter e build Android requerem GitHub Actions.
