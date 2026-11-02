# Vigia IA 1.0.330+330 — Recepção H.264 e vigilância RTSP

- Monitor e tela MCRP agora podem receber H.264 HTTP Annex-B do Minha Câmera com LibVLC `:demux=h264`, além do MJPEG existente, sem duplicar o player.
- A fonte monitora `x-stream-codec` pelo status do transmissor e alterna para `/h264/<token>` ou `/live/<token>` de forma automática; HTTP 409 em MJPEG aciona o H.264 mesmo sem telemetria.
- Com a IA ligada, os snapshots do LibVLC são convertidos para RGB sem reencodar o vídeo. Quando a IA está desligada, são feitas sondagens limitadas para confirmar vídeo.
- RTSP local: timeout do primeiro quadro mesmo se VLC reportar `isPlaying`, e detecção de possível congelamento após 18s sem novo snapshot. Mantido teto de três reconexões.
- Integrações Media3, mapas, APIs, sensores, notificações, gravação e navegação preservadas.

## Limitações

Os testes de codec, de freeze e da captura dependem do comportamento do LibVLC no celular. Snapshot indisponível pode provocar falso positivo do watchdog; a captura pode repetir um quadro antigo se o VLC estiver congelado. É necessário validar em Android real. Não inclui MP4 H.265→H.264 nem gravação nova. O aplicativo não foi compilado localmente quando o SDK Flutter esteve ausente.
