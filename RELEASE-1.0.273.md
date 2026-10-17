# Vigia IA 1.0.273+273

## Integração nativa do Minha Câmera (primeira entrega)

- Transmissor MCRP v1 nativo Kotlin integrado como serviço foreground Android de câmera, com captura headless independente da Activity e do Flutter.
- O modo nativo é **experimental e opcional**; modo Dart anterior permanece como alternativa sem regressões intencionais.
- QR/URL privada `http://<ipv4-local>:8765/live/<token>` para conexão do receptor Vigia IA, com controles remotos: FPS, qualidade, zoom, lanterna, REC, foto, câmera frontal/traseira, Eco e status.
- Gravação e biblioteca remota limitadas aos arquivos criados pela instalação do Vigia IA. Mídia antiga do pacote Minha Câmera não é migrada automaticamente.
- Serviço Android permanece ativo após apagar a tela e quando Flutter deixa de estar em primeiro plano, sujeito a restrições do SO e otimização de bateria; a estabilidade precisa ser comprovada no Redmi A3.
- Tela própria de ativação, confirmação de início, QR e diagnóstico simples; protege contra iniciar o transmissor Dart na mesma porta simultaneamente.
- Nesta etapa, preview local do serviço nativo fica desabilitada para reduzir consumo; a prévia aparece no segundo celular.

## Não concluído

- Ainda não houve `flutter analyze`, `flutter test` ou compilação Android com SDK; dependências nativas/Gradle devem ser validadas no GitHub Actions.
- Testes físicos: câmera com tela apagada, reconexão, FPS, telemetria, gravação e controle remoto pelo segundo celular.
- Não desinstale Minha Câmera antes de validar paridade. Migração de gravações, aprimoramentos de PiP e maior integração de UI ficam para versões seguintes.
