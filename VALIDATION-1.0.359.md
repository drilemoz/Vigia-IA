# Validação 1.0.359+359

- Base inspecionada: 1.0.358+358 (`pubspec.yaml`, `AGENTS.md`, `tool/version_baseline.json`, integridade de ZIP).
- Parser ORS: só mantém altitudes numéricas/finita na mesma posição de vértices geográficos válidos.
- Codec JSON de rota: preserva métricas de altitude e ainda lê arquivos schema 1 anteriores sem estas chaves.
- Índice por etapa: distribuição de desnível somente a partir de pares consecutivos válidos; cobertura parcial é medida, nunca interpolada através de lacunas.
- Meteorologia: sem chamada automática; ETA depende da data de saída escolhida; consultado no ponto intermediário de cada etapa, até oito solicitações por toque; resultados não disponíveis fora da janela permanecem ausentes.
- Persistência da viagem: previsão e data opcionais; conteúdo inválido é ignorado individualmente sem corromper a viagem.
- Testes: `tool/test_trip_terrain_weather_359.py`, `test/trip_terrain_weather_359_test.dart`. Executar `tool/verify_project.sh` e registrar resultado; `flutter analyze`/`flutter test`/Android SDK não disponíveis localmente.
