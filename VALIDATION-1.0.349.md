# Validação — Vigia IA 1.0.349+349

- Fonte baseada na 1.0.348+348, preservando os módulos existentes.
- Novos testes Dart: `test/map_hud_refresh_policy_test.dart` e `test/map_camera_source_policy_test.dart`.
- Contrato Python: `tool/test_map_background_refactor_349.py`; contrato de HUD da 1.0.348 atualizado para a nova organização sem perda da prevenção contra manobra GPS obsoleta.
- `bash tool/verify_project.sh`: **aprovado (exit 0)**. Suíte Python consolidada: **469 testes executados, 1 ignorado, 0 falhas**.
- Testes direcionados de versionamento, ciclo de vida, HUD e câmeras: **22 aprovados**, além das regressões incluídas na suíte completa.
- Integridade CRC do ZIP: verificada na geração do pacote.
- SDK Flutter/Android não disponível localmente; Flutter analyze, Flutter test, APK e testes de sensores/GPS no aparelho pendentes.

- Testes locais validam contratos de código, não comprovam economia de bateria. A suspensão de Timer/EventChannel no Android deve ser conferida no dispositivo após compilar.
