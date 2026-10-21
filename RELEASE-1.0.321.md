# Vigia IA 1.0.321+321 · Correção do teste de navegação no build 269

## Falha verificada no GitHub Actions

O build 269 passou nos testes Python e no `flutter analyze --fatal-infos --fatal-warnings` (`No issues found!`), mas o `flutter test --coverage` terminou com 588 testes aprovados e 1 falha em `test/main_navigation_bar_test.dart`. A pilha de execução indicou três `Timer (duration: 0:00:03.000000)` pendentes, criados por `AutomaticDiagnosticsService._send` através do `setUiSection`, invocado quando o teste tocou nas abas Câmeras, Galeria e Mapas. A infraestrutura `FakeAsync` exige não restarem timers quando um teste termina.

## Correção

- O teste de widget adiciona resposta nativa simulada ao canal `vigiaia/native`, recolhe as chamadas e restaura o handler após o teste.
- Garante que as três abas continuem selecionáveis e emitam os eventos `acao=aba_Câmeras`, `acao=aba_Galeria` e `acao=aba_Mapas`, sempre com a região `area=navegacao`.
- Aguarda a estabilização do widget antes do final para evitar timers de transporte de diagnóstico deixados pendentes.
- Adicionada regressão `tool/test_build269_navigation_timers_321.py` ao verificador preventivo.
- Versionamento 1.0.321+321 sincronizado, mantendo o histórico de releases.

## Limitações

Nenhum componente de produção foi modificado nesta correção, para preservar a gravação de interações em Android real. O Flutter SDK e a compilação Android estão indisponíveis no ambiente local; é necessário confirmar a suíte Flutter e o APK no próximo GitHub Actions.
