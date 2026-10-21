# Vigia IA 1.0.319+319 · Diagnóstico de menus e cliques

## Escopo

- Registrar toda interação curta de toque reconhecida pelo Flutter quando não houver teclado/editor ativo; marcar aba ativa e região aproximada 3×3. Arrastes e gestos longos não são considerados cliques.
- Identificar semanticamente a navegação principal, opções do menu de câmera, monitorar, QR, busca LAN, cadastro e transições/estados Media3.
- Eventos importantes têm persistência nativa sem o atraso de 2 segundos. O último toque **recebido pelo MethodChannel** ganha checkpoint síncrono próprio; preserva o máximo possível se houver encerramento logo após o clique.
- Mostrar interações anteriores e atuais no relatório manual, preservando eventos no relatório automático/recuperação de incidente.
- Limitar a 120 eventos na sessão; não registrar dados digitados, teclado, senhas, URLs, imagens, áudio, coordenadas GPS ou pixels exatos. Não há envio remoto.

## Validação local

- `tool/verify_project.sh`: aprovado com 333 testes Python (329 aprovados, 4 ignorados) e verificadores adicionais.
- Widget-test da captura de toque incluído, mas ainda não executado sem Flutter SDK.

## Limitações conhecidas

- Não há garantia de capturar um toque que jamais chegou ao canal nativo antes da interrupção total do processo.
- Os toques genéricos identificam apenas a região; os menus explicitamente instrumentados têm nome. Alguns botões ainda aparecem apenas como toque por região.
- A gravação de cada clique em disco poderá aumentar a escrita e deve ser medida no Redmi A3 e no receptor.
- Esta versão não substitui VLC nem altera a prévia RTSP obrigatória. Media3 continua modo experimental de teste.
- Compilação Flutter/Android, testagem em aparelho e reprodução RTSP devem ser verificadas em CI/hardware.
