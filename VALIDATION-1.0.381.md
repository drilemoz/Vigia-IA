# Validação Vigia IA 1.0.381+381

## Build Android 325

O log confirma falha em `tool/check_route_preview_229.py`, contrato `comparação declarando limites`. O texto exibido pelo aplicativo já havia sido atualizado para advertir sobre pavimento desconhecido, relevo, segurança e condição atual não verificados em campo. A guarda agora exige os dois fragmentos que compõem esse aviso, mantendo os demais 10 contratos.

Base local e GitHub main: 1.0.380+380. Drive: ZIP 1.0.376.

- 590 testes Python: 589 aprovados, 1 ignorado (Dart SDK indisponível), zero falhas.
- 53 scripts Python independentes invocados pelo workflow aprovados.
- SDK Android 36 preservado, metadados sincronizados.
- Sem Flutter/Dart SDK local: Flutter Analyze, testes Flutter e compilação APK pendentes do CI.
