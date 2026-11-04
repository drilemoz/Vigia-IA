# Verificações — Vigia IA 1.0.339+339

- Base: ZIP da versão 1.0.338+338 fornecido pelo usuário, logs de 1.0.336 e 1.0.337.
- Implementado `RetainedMbTilesTileProvider`, troca de provedores com `release()` e exclusão de arquivos após drenagem.
- Alterado MapLibre Android de HC puro para TextureView/TLHC e removida opacidade inicial zero; resets de renderer desnecessários eliminados.
- Verificações direcionadas: **40 testes Python aprovados** (`test_map_lifecycle_339`, `test_offline_mode_download_338`, `test_release_consistency_296`, `test_navigation_ptbr_compact_337`, `test_build281_flutter_analyze_336`, `test_api_backup_map_ui_334`).
- `tool/check_version_sync.py` e `tool/check_release_consistency.py`: **aprovados**.
- `bash tool/verify_project.sh`: grupos iniciais passaram, porém a execução integral excedeu o limite do ambiente e **não pode ser considerada aprovada**.
- Flutter SDK ausente: `flutter analyze`, `flutter test`, compilação Android e testes físicos **não executados**.
- Não há teste de dispositivo nem confirmação de que todas as condições de ANR desapareceram.
