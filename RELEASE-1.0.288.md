# Vigia IA 1.0.288+288

- Controle MCRP de pausa e início de transmissão com confirmação do estado remoto. Durante a pausa, o transmissor mantém o serviço e QR, sem capturar vídeo nem manter wake locks.
- Ao vivo retoma a última câmera escolhida, tenta reconectar e utiliza a câmera local se estiver inacessível, preservando a preferência para o próximo acesso.
- Telemetria de temperatura da bateria e prevenção de pausa enquanto gravação está ativa.
- Compilação Flutter e APK no GitHub Actions ainda não confirmadas.
