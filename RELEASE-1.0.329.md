# Vigia IA 1.0.329+329 — Estabilidade da conexão RTSP

- Reconexões LibVLC com intervalo 2/5/10 s, máximo três tentativas seguidas sem quadro confirmado.
- Prazo de 20 s para a abertura inicia após anexar a superfície nativa; antes disso o processo não é reiniciado.
- Relatórios RTSP distinguem estado "reproduzindo" de primeiro quadro capturado; apenas snapshot válido reinicia orçamento de tentativas.
- Snapshot de confirmação leve na segunda câmera sem iniciar processamento de IA.
- Mensagens emitidas para a UI deixam de incluir erro nativo/URL, que poderiam conter credenciais.
- Media3 permanece em tela de testes independente, pois não alimenta ainda os frames RGB do monitoramento.
- Preservados mapas, áudio, MCRP, sensores, câmeras locais e preferências.

## Limites

Falha do snapshot não significa ausência de imagem; VLC pode exibir vídeo mesmo sem capturas. Não há alteração de codec H.265 nem conversão H.264/MP4 nesta fase. Flutter analyze/test/build e avaliação no Android ainda são necessários.
