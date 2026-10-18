# Vigia IA 1.0.278+278

## Apenas um modo transmissor visível

- A tela Transmissão abre diretamente o serviço nativo, com QR recolhível, REC e controles locais de emergência. A tela antiga de prévia em Flutter não tem mais rota na interface.
- Botão Alterar modo funciona mesmo para a transmissão como modo inicial, sem derrubar a câmera por engano.
- Nomes padrão de novas câmeras remotas padronizados no cadastro, no seletor do Ao vivo e no monitor; nomes personalizados continuam respeitados.
- QR MCRP, reprodução MJPEG e gravação remota preservados.

## Validação

- Regressão das rotas e rótulos de câmeras adicionada.
- A compilação completa Flutter/Android precisa de confirmação pelo GitHub Actions.
