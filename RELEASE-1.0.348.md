# Vigia IA 1.0.348+348 — conectividade, autonomia e segurança

## Alterações
- Status de internet baseado em HTTPS com resposta 204 e TLS verificado, sem aceitar só DNS ou portal cativo; duas origens e timeout curto. O status não confirma que cada API de rota esteja operacional.
- No acompanhamento passivo do mapa, GPS usa precisão moderada e distância mínima de 35 m. Ao iniciar rota ou gravação, restaura alta precisão/8 m, sem streams simultâneos. Sem economia garantida até teste de bateria em aparelho.
- Receiver de recuperação interno não exportado; receptor externo processa somente BOOT_COMPLETED e MY_PACKAGE_REPLACED, e continua respeitando a configuração e agenda.
- HUD de mapa ocioso evita reconstruções gerais a cada 10 s; com navegação, gravação ou GPS recente continua atualizando a cada 10 s.
- GitHub Actions: pushes automáticos da mesma branch cancelam os anteriores; execuções manuais são independentes.

## Limites
- Não adiciona motor de roteamento viário offline. Mapas MBTiles não são uma rede viária roteável; salvamento/reuso de rotas continua existente.
- `usesCleartextTraffic=true` permanece para compatibilidade com câmeras HTTP locais e algumas transmissões de rádio; não há garantia geral de criptografia para dispositivos LAN.
- Flutter analyze/test/build do Android precisam ocorrer no GitHub Actions se o SDK não estiver disponível no ambiente.
