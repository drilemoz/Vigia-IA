# Vigia IA 1.0.276+276

## Tela de transmissão simplificada e gravação remota

- Status do serviço nativo, tempo, bateria, temperatura, FPS, estado de gravação e câmera em painel compacto.
- QR e endereço privado em seção expansível; controles locais de emergência em seção própria. Nenhuma prévia local é criada.
- Ao vivo: iniciar/parar REC por MCRP v1, acompanhamento por `X-Recording`, confirmação após POST e aviso de status incerto quando a conexão é perdida. Não reenvia POST de gravação automaticamente.
- Identificação visual Vigia IA/câmera remota em vez de Minha Câmera nas telas ativas; formatos de QR legado continuam compatíveis.
- Gravação iniciada no transmissor continua quando a conexão do receptor cair, desde que o serviço e a gravação permaneçam ativos. Comandos novos exigem comunicação local.

## Verificação

- `tool/verify_project.sh` aprovado, incluindo 165 testes Python na suíte preventiva principal e testes direcionados de controle remoto/identidade.
- Necessária recompilação Android pelo GitHub Actions, `flutter analyze`, `flutter test` e testes físicos no Redmi A3.
