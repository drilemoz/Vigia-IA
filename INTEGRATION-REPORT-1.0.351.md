# Relatório de integração — 1.0.351+351

## Evidência de recuperação

- Fonte oficial de base: 1.0.350+350, verificada no diretório de trabalho e no Drive.
- Fonte de referência para RTSP: 1.0.341+341 (linha antiga, não usada como base).
- Arquivos originais da 1.0.350: **1.291**.
- Arquivos da 1.0.350 que faltam na 1.0.351: **zero**.
- Nota: alguns arquivos da 1.0.350 foram **modificados intencionalmente** para levar o RTSP e o novo versionamento; não foram substituídos por código de mapas mais antigo.

## Arquivos presentes na 1.0.350 mas ausentes na 1.0.341

- `RELEASE-1.0.342.md`
- `RELEASE-1.0.343.md`
- `RELEASE-1.0.344.md`
- `RELEASE-1.0.345.md`
- `RELEASE-1.0.346.md`
- `RELEASE-1.0.347.md`
- `RELEASE-1.0.348.md`
- `RELEASE-1.0.349.md`
- `RELEASE-1.0.350.md`
- `VALIDATION-1.0.342.md`
- `VALIDATION-1.0.343.md`
- `VALIDATION-1.0.344.md`
- `VALIDATION-1.0.345.md`
- `VALIDATION-1.0.346.md`
- `VALIDATION-1.0.347.md`
- `VALIDATION-1.0.348.md`
- `VALIDATION-1.0.349.md`
- `VALIDATION-1.0.350.md`
- `android/app/src/main/kotlin/com/vigiaia/app/MonitorBootRecoveryReceiver.kt`
- `lib/services/bike_trip_editor_bridge.dart`
- `lib/services/bike_trip_schedule_settings_service.dart`
- `lib/services/map_camera_source_policy.dart`
- `lib/services/map_hud_refresh_policy.dart`
- `lib/services/retained_mbtiles_tile_provider.dart`
- `lib/widgets/map_layer_picker_panel.dart`
- `test/bike_trip_unified_flow_test.dart`
- `test/diagnostic_recovery_v345_test.dart`
- `test/map_camera_source_policy_test.dart`
- `test/map_hud_refresh_policy_test.dart`
- `test/map_layer_picker_panel_test.dart`
- `test/retained_mbtiles_provider_lifecycle_test.dart`
- `tool/android/MonitorBootRecoveryReceiver.kt`
- `tool/test_app_metadata_dynamic_342.py`
- `tool/test_build288_flutter_analyze_343.py`
- `tool/test_build289_preview_card_344.py`
- `tool/test_build291_recovery_dialog_346.py`
- `tool/test_build294_flutter_analyze_350.py`
- `tool/test_connectivity_energy_security_348.py`
- `tool/test_diagnostic_recovery_345.py`
- `tool/test_map_background_refactor_349.py`
- `tool/test_map_layer_picker_347.py`
- `tool/test_map_lifecycle_339.py`
- `tool/test_unified_bike_planning_341.py`

## Áreas de alteração intencional

- Câmeras: modelos `CameraEndpoint`/`VideoSourceConfig`, seleção, cadastro, transporte LibVLC, controladores e entradas da tela/mapa; migração de preferência TCP/UDP por câmera.
- Versão/release: `pubspec.yaml`, metadados, Novidades/Sobre, histórico e contratos de testes atualizados para 351.
- Prevenção da regressão: regra em `AGENTS.md` e `tool/check_latest_baseline.py` com a base comprovada registrada em `tool/version_baseline.json`.
- Mantidos da 350 sem substituição: `retained_mbtiles_tile_provider.dart`, `map_hud_refresh_policy.dart`, `bike_trip_editor_bridge.dart`, `bike_trip_schedule_settings_service.dart`, `map_layer_picker_panel.dart` e rotinas de diagnóstico.

## Validação

- Ver `VALIDATION-1.0.351.md` para resultado dos testes e limitações de build.
