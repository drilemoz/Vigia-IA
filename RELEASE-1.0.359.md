# Vigia IA 1.0.359+359 — Relevo e consulta meteorológica por etapa

Atualiza o Planejamento pessoal de cicloviagem: preserva relevo real das rotas ORS ao salvar, exibe total de subida/descida e — quando houver altitude por vértice — estima o desnível diário por geometria, informando cobertura parcial. Estimativas de pedal continuam baseadas na velocidade escolhida.

A data de partida é selecionável. Com o botão **Consultar clima**, o app consulta manualmente o Open-Meteo no meio de cada etapa elegível (até 8 por toque e dentro dos próximos dias), exibe temperatura, chance de chuva, precipitação e rajadas, e salva a previsão com data para consulta offline. Não realiza chamadas automáticas ou localização em segundo plano. Previsões armazenadas envelhecem; não são avisos oficiais e não garantem segurança ao longo de toda a rota.

Atenção: somente rotas ORS com altitude no GeoJSON permitem repartir desnível por dia. O aplicativo não calcula ainda tempo realista para subidas/descidas, nem prevê tempestades severas fora do horizonte meteorológico. Sem SDK Flutter disponível no ambiente local, análise estática Flutter e compilação APK deverão ser confirmadas no CI.
