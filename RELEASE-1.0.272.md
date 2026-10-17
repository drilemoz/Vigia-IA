# Vigia IA 1.0.272+272

## Implementado

- Controle do Redmi A3 diretamente em Ao vivo para fontes Minha Câmera MCRP autenticadas.
- Painel unificado para vídeo remoto: REC, foto, frontal/traseira, Eco, lanterna, zoom (+/- 10%), resolução e FPS; telemetria de zoom/FPS/bateria.
- Controles em retrato e acesso pelo menu em paisagem/tela cheia.
- Protocolo MCRP v1 preservado. Nenhum comando arbitrário ou conexão extra de vídeo é criada.

## Pendências/limitações

- O Redmi A3 continua usando Minha Câmera como transmissor: ainda não houve fusão do serviço Kotlin.
- Ao vivo continua em MJPEG; troca de codec fica na tela MCRP, pois H.264 interromperia a análise no monitor.
- Girar e espelhar a prévia estão disponíveis somente na tela MCRP independente; PiP e controle local do visor no Ao vivo ainda não foram migrados. O modo transmissor integrado não faz parte desta fase.
- Flutter analyze/test, build APK e testes físicos com as duas telas pendentes.
