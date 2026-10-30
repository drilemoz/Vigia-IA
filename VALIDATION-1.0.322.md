# Validação 1.0.322+322

- Base: ZIP da 1.0.321+321; mudanças centradas na navegação da bicicleta e no gravador diagnóstico.
- Testes estruturais novos: `tool/test_map_diagnostics_navigation_322.py` (6 casos aprovados).
- Suíte geral `python3 -m unittest discover -s tool -p test_*.py -q`: 346 testes (345 aprovados, 1 ignorado).
- `tool/verify_project.sh`: execução integral aprovada na base atual antes do último ajuste de amostragem antecipada; após o ajuste, testes estruturais, suíte Python e PSI Kotlin aprovados.
- Sintaxe Kotlin PSI (`AppDiagnostics.kt`, `VigiaApplication.kt`, `DiagnosticPolicy.kt`): sem erros sintáticos (não substitui compilação Android).
- Pendente: `flutter analyze`, `flutter test`, Gradle/Android e reprodução em aparelho real.
