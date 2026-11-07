# Validação 1.0.368+368

- Base 1.0.367+367 verificada no ZIP local, Drive e repositório antes da alteração.
- Modificação funcional restrita à altura e ao limite proporcional de `Próximos pontos`, em `lib/screens/map_monitoring_screen.dart`.
- Teste estrutural `tool/test_nearby_panel_height_368.py` para impedir regressão nas alturas.
- Sem SDK Flutter/Dart instalado localmente: `flutter analyze`, `flutter test` e build Android permanecem pendentes da execução pelo GitHub Actions.

## Resultado executado nesta entrega

- `bash tool/verify_project.sh`: **aprovado**, código de saída 0.
- Suíte principal Python: **551 testes**, sendo **550 aprovados e 1 ignorado**.
- `tool/test_nearby_panel_height_368.py`: **2 testes aprovados**.
- `tool/check_map_radio_219.py`: aprovado após atualizar a expectativa antiga de altura, preservando as demais verificações.
- `tool/check_latest_baseline.py`, `tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovados.
- Não há SDK Flutter/Dart nesta execução, portanto `flutter analyze`, `flutter test`, aparência em aparelho e build APK ainda dependem do CI.
