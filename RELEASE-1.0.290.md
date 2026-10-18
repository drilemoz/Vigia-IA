# Vigia IA 1.0.290+290

- Modo Transmissor Exclusivo: seleção persistente após reiniciar, isolamento antes de inicializar módulos opcionais; bloqueia novas leases do monitoramento, rádio, ESP32 e outros trabalhos no Vigia IA.
- Entrada e saída protegidas: enquanto transmite não navega para Mapas/Ao vivo, e a saída exige confirmação e finalização da captura e gravação antes de liberar o modo.
- MJPEG/H264: contador de espectadores reais separado de consultas HTTP; na ausência de espectadores e de REC, mantém apenas quadro de manutenção a cada 2,5 segundos para preservar disponibilidade do MCRP.
- Política térmica combina temperatura de bateria e status térmico do Android, reduz o processamento em WARM/HOT e encerra com finalização segura se o sistema reportar emergência térmica.
- Regras de segundo plano preservam a operação com tela apagada, pareamento QR e gravação local quando acionada.
- Não comprovada economia de bateria ou redução de temperatura em aparelho real; testes do Redmi A3 e Flutter/Android CI continuam pendentes.

Detalhes técnicos: `docs/TRANSMITTER_EXCLUSIVE_290.md`.
