# Vigia IA 1.0.269+269

**Ao vivo renovado, mapa compacto no botão Mapa, áudio em popup e correção ao abrir fotos de eventos.** Código-fonte Flutter, sem APK compilado.

- O botão **Mapa** da tela Ao vivo agora alterna diretamente para o mapa compacto embutido, em vez de abrir a lista de pontos próximos como ação principal.
- O botão **Áudio** agora abre um popup/modal deslizante, no mesmo estilo do mapa, permitindo ativar, silenciar e editar os áudios e falas sem sair do Ao vivo.
- O painel **Status da sessão** foi reorganizado com visual renovado, chips/resumos rápidos, ícones por informação e melhor alinhamento em Saúde, Vídeo e dispositivos.
- A abertura de mídia em **Eventos** passa a priorizar a foto/snapshot do evento quando disponível, reduzindo falhas ao tocar nas fotos; arquivos ausentes agora mostram placeholder seguro.
- Mantidos o mapa completo, o painel detalhado de vídeo e as configurações avançadas existentes.

Validação local com checagens estruturais e empacotamento do código-fonte; `flutter analyze`, `flutter test` e build Android devem ser confirmados no CI / aparelho.
