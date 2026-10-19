# Vigia IA 1.0.299+299 · RTSP assistido

- Cadastro RTSP mais compacto com IP, porta, caminho em lista e opção personalizada.
- Colar URL preenche campos, inclusive credenciais codificadas corretamente.
- Buscar no Wi-Fi integra descoberta ONVIF e RTSP/OPTIONS da LAN, selecionando candidatos sem inventar a URL de vídeo.
- Detectar stream testa caminhos conhecidos com RTSP DESCRIBE/SDP, incluindo autenticação Basic/Digest MD5 anunciada pelo dispositivo.
- Testar URL mostra resultado exato: vídeo anunciado, 401/403, 404 ou sem resposta.
- A câmera continua podendo ser salva sem comprovante de vídeo, pois a compatibilidade do player só é testável ao abrir.
- Transporte TCP habilitado por padrão; compatibilidade permite transporte padrão VLC e decodificação por software por câmera.
- Nenhuma varredura de rede é feita em segundo plano; testes direcionados à LAN sob toque.
- Compilação Flutter/Android, perfil ONVIF autenticado e teste em câmera real ainda pendentes.
