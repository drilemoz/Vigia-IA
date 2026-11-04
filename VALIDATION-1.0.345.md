# Vigia IA 1.0.345+345 — Validação do diagnóstico Android

- Testes direcionados Kotlin/JVM de `DiagnosticPolicy`: classificações, severidade, PID, horários, SIGKILL inconclusivo, redação de dados sensíveis e ausência de alarmes por parada solicitada.
- Python `tool/test_diagnostic_recovery_345.py`: contratos de correlação, política de avisos, tentativas, reconsulta e versionamento.
- `test/diagnostic_recovery_v345_test.dart`: 4 cenários novos (evento informativo, incidente legado de memória em cache, crash de versão antiga, recuperação após indisponibilidade temporária) — pendentes de `flutter test` no CI.
- `tool/verify_project.sh`: **aprovado (exit 0)** em 2026-11-04. Suíte consolidada Python: **453 testes (452 aprovados, 1 ignorado), 0 falhas**. Verificação de versão e catálogo de Novidades aprovadas.
- Sem SDK Flutter local, os comandos `flutter analyze`, `flutter test` e compilação Android serão confirmados no próximo GitHub Actions.
