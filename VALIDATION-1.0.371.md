# Validação Vigia IA 1.0.371+371

- Evidência: arquivo `Vigia-IA-Android-APK-316-logs.zip`, etapa `Verificação preventiva` do workflow Android APK 316.
- Falha original: `FALHA 229: sem status de acesso por estrada`, emitido por `tool/check_route_preview_229.py`.
- Causa: a versão 1.0.370 reescreveu a advertência de proximidade, fazendo falhar um teste textual que exigia a frase anterior.
- Correção: aviso completo restaurado dentro de `Localidades e pontos de apoio` em `lib/screens/trip_planning_screen.dart`; a UI recolhível e os fluxos de dados permanecem inalterados.
- Teste estrutural alvo: 11 contratos aprovados.
- SDK Flutter/Android indisponível no ambiente de entrega; compilação, `flutter analyze`, `flutter test` e teste no celular pendentes de novo workflow.
- Na verificação integral, o teste `test_trip_stop_check_362.py` sinalizou outro texto reformulado na 1.0.370; aviso de conferência antiga restaurado na mesma correção.
- Verificação integral `bash tool/verify_project.sh`: **aprovada, código de saída 0** (09/11/2026). Bateria `unittest discover` executou 561 testes com 560 aprovados e 1 pulado por ausência do Dart SDK; outros verificadores e testes específicos de CI também foram executados com êxito.
- Integridade do ZIP final e referências de versão verificadas no empacotamento.
