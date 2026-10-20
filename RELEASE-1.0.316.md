# Vigia IA 1.0.316+316 · Buildfix do workflow Android APK 264

## Falha comprovada

O workflow APK 264 passou pelo bootstrap Android, 311 testes Python preventivos, `flutter analyze --fatal-infos --fatal-warnings` (nenhum apontamento) e download/preparação dos modelos. A execução de `flutter test --coverage` interrompeu com 3 falhas de `pumpAndSettle timed out`, todas em `test/diagnostic_recovery_host_test.dart`: “Agora não” (linha original 44), erro ao exportar (linha original 69) e exportação correta (linha original 94). Resultado do workflow: 585 aprovados, 3 falhas; compilação do APK não foi iniciada.

## Causa e ajuste

A tela inicial de `DiagnosticRecoveryHost` mostra `CircularProgressIndicator` enquanto um incidente pendente espera decisão. O aviso do diagnóstico é um `showDialog` sobre essa árvore animada. `pumpAndSettle` exige que nenhuma nova frame esteja agendada, condição que não se cumpre nesse estado. Não é evidência de travamento do aplicativo em produção.

- Introduzida `waitForRecoveryDialog(tester)` que bombeia um máximo de 20 quadros com intervalos de 50 ms, verifica o aviso por texto e avança a transição (350 ms). Se o diálogo não aparecer, o teste falha explicitamente.
- No cenário de exportação que retorna falha e conserva o modal aberto, substituído o `pumpAndSettle` por avanço finito de frames.
- Após fechar o diálogo, mantém-se `pumpAndSettle` e asserts reais de exportação/acknowledge e abertura do app.
- Acrescentada verificação estrutural de regressão no `tool/verify_project.sh`.
- Não foram alteradas `lib/widgets/diagnostic_recovery_host.dart`, diagnósticos, coleta, exportação, IA, mapas, vídeo, gravação, RTSP ou armazenamento.

## Validação

Aguardando CI do Flutter e APK, pois não há Flutter SDK nesta sessão. Ver `VALIDATION-1.0.316.md`.
