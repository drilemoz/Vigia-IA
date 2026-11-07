# Vigia IA 1.0.361+361 — Divisão inteligente de etapas offline

- Controle **Divisão inteligente dos dias**, reversível, usa a velocidade configurada e a reserva de tempo por 100 m de subida realmente documentada no perfil da rota; sem dados de altitude, não supõe subidas.
- Quantidade de dias e pontos de corte estimados pelo esforço acumulado, com preferência por cidades e apoios próximos do traçado quando isso não ultrapassa o limite de horas de pedal ou inviabiliza as etapas restantes.
- Se não existir candidato adequado, a parada continua aproximada e recebe aviso; proximidade em linha reta não comprova acesso pela via, água, local seguro ou hospedagem.
- A prévia do mapa exibe finais de etapa numerados (até 80), diferenciando paradas aproximadas de candidatos próximos; a legenda não garante acesso.
- Dados permanecem disponíveis offline: sem ativação automática de GPS, rede ou IA. Consultas de meteorologia seguem manuais e são invalidadas ao alterar o itinerário.
- Compatibilidade JSON com viagens antigas, novo cache de plano por objeto, versionCode e Novidades sincronizados.
- Dependências externas, políticas de cache Stadia e módulos de câmera/ESP32 não foram alterados. APK e análises Flutter dependem do CI.
