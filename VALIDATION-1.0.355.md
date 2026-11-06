# Validação de fonte — 1.0.355+355

- Base: código-fonte 1.0.354+354 já empacotado e conferido, com os mapas offline preservados.
- Evidência: `Vigia-IA-Android-APK-302-logs (1).zip` indica somente falha Python em `test_trip_planning_wizard_285.py`, exigência do token `_routeMap(route)`; nenhuma etapa Flutter/Gradle de compilação chegou a executar.
- Correção: contrato de widget preserva intenção, deixando de fixar nome de variável que não faz parte da API do recurso.
- `tool/verify_project.sh`: aprovado com saída 0. 494 testes Python executados, além de contratos estruturais e testes Kotlin/JVM incluídos pelo verificador.
- Testes direcionados do assistente 285, regressão 355 e offline 354: 15 aprovados.
- Verificador de versão: 1.0.355+355 consistente.
- `flutter analyze`, `flutter test` e compilação do APK ainda pendentes: SDK Flutter/Android indisponível neste ambiente.
