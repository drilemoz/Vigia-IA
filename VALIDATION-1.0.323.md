# Validação Vigia IA 1.0.323+323

- Fonte-base: `VigiaIA-v1.0.322-322-Mapas-Navegacao-Diagnostico-Recursos-source.zip`.
- Regressões: `tool/test_active_bike_pace_323.py` e `test/bike_trip_planner_test.dart`.
- Verificações executadas e resultados finais devem ser atualizados após validação.
- **Limite:** Flutter SDK e Android SDK ausentes; sem prova de `flutter analyze`, `flutter test`, APK gerado ou interface validada em aparelho real.

## Resultados locais

- `python3 -m unittest discover -s tool -p 'test_*.py' -q`: 350 testes, 349 aprovados e 1 ignorado.
- `tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovados.
- `PATH=/usr/local/bin:/usr/bin:/bin:/opt/pyvenv/bin bash tool/verify_project.sh`: aprovado. Compilador Kotlin removido do PATH desta execução para evitar bloqueio do executor local, não substitui compilação Kotlin/Android.
- `bash -n tool/verify_project.sh`: aprovado.
- Regressão dirigida final `tool/test_active_bike_pace_323.py` e `tool/test_map_diagnostics_navigation_322.py`: 10 testes aprovados.
- APK, `flutter analyze` e `flutter test` precisam ser executados no CI antes de classificar a entrega como compilada.
