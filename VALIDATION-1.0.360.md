# Validação Vigia IA 1.0.360+360

- Base: ZIP fonte 1.0.359+359 conferido localmente, preservado na pasta do Google Drive. Nenhum arquivo antigo removido.
- Cobertura Dart adicional `test/trip_effort_reserve_360_test.dart`: elevação válida/parcial/ausente, soma de reserva, avisos de tempo/pernoite, formato JSON e compatibilidade legada.
- Contratos estáticos: `tool/test_trip_effort_reserve_360.py`; execução integral: `tool/verify_project.sh`.
- O ambiente local **não dispõe do SDK Flutter/Dart**; testes Dart e compilação Android precisam do workflow.
- Reservas de subida são hipóteses parametrizadas pelo usuário, não medições ou garantias de tempo de viagem. O limite de chegada não corresponde necessariamente ao pôr do sol.

## Resultado local de 06/11/2026

- `python3 -m unittest discover -s tool -p 'test_*.py' -q`: 517 testes, 516 aprovados, 1 ignorado.
- `bash tool/verify_project.sh`: concluído com código de saída 0.
- `tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovados.
- Sem SDK Flutter/Dart: análise Dart, testes Flutter e build Android não executados localmente.
