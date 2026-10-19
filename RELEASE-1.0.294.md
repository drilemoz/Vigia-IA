# Vigia IA 1.0.294+294 · Interfaces e descoberta LAN

- Barra principal com cinco destinos. Configurações no topo direito das telas principais; remover Home e menu redundante do Ao vivo.
- Controles MCRP: Lanterna com seletor modal e estado no card; Vídeo reúne resolução e FPS; opção experimental de possível pessoa com ícone de rosto azul/neutro.
- Estado remoto pausado em painel contrastante, AO VIVO exibido apenas com fonte de vídeo ativa e cronômetros da transmissão/gravação obtidos do MCRP.
- A telemetria da câmera recebeu melhorias de distribuição e ícones maiores; seletor de modelos de IA identificado por ícone de cérebro.
- Scanner LAN checa a porta TCP 8765 como **possível** transmissor Vigia IA sem presumir autenticidade, envia sondagens UDP repetidas, classifica gateway quando Android o informa, e mantém QR obrigatório.
- Cadastro RTSP passa a respeitar sugestão de endereço inicial e nunca inventa caminho de stream.
- Diagnóstico de IA é exportado automaticamente ao encerrar para Downloads/Vigia IA no Android, sem gravação contínua durante inferência.

## Restrições e segurança

- Porta 8765 aberta é apenas indício de Vigia IA. Não concede acesso; usuário confirma e faz pareamento por QR.
- RTSP `rtsp://IP:porta/` não prova a URI final; descobrir caminho de vídeo requer ONVIF Media GetStreamUri ou informação do fabricante.
- Confirmação de FPS, resolução e comandos exige teste em dois aparelhos e compilação pelo workflow.
- Flutter analyze/test e APK dependem do ambiente CI, se SDK ausente localmente.
