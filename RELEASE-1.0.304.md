# Vigia IA 1.0.304+304

## Correção do workflow Android-APK-255

- O Flutter Analyze do build 255 aprovou a versão 1.0.303. O Flutter Test teve 570 resultados aprovados e uma falha no widget test dos controles remotos.
- Causa: `find.text('Zoom')` encontrava **dois** widgets: botão do painel de ações e título do modal aberto. A expectativa `findsOneWidget` era incorreta.
- Solução: o modal compacto possui uma `Key` estável e o teste procura seu título dentro do modal (`find.descendant`). O título do botão de fundo pode coexistir normalmente.
- Mantidos o botão X, zoom 0–100%, restauro 1× e os comandos remotos de zoom/vídeo/gravação/lanterna.
- Acrescentados testes de regressão que barram buscas ambíguas e verificam a sequência de comandos.

## Limites da validação

- Analisador Flutter, Flutter Test e compilação do APK da versão 1.0.304 ainda precisam ser executados no GitHub Actions. Sem SDK Flutter local.
