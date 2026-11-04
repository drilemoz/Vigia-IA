# Verificações — Vigia IA 1.0.338+338

- Base versionada 1.0.337+337. Alterações: escolha de renderizador, cobertura offline, download, atualização segura, testes e metadados.
- `python -m unittest discover -s tool -p "test_*.py" -q`: **430 testes executados; 429 aprovados e 1 ignorado**, resultado `exit 0`.
- `tool/test_offline_mode_download_338.py`: **9 contratos direcionados aprovados**, incluindo seleção correta do renderizador, câmera, cobertura e preservação de modo após exclusão do último pacote.
- `bash tool/verify_project.sh`: **aprovado (exit 0)**, incluindo versionamento, central de APIs, câmeras, IA, navegação e verificações complementares.
- `tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovados.
- Testes Dart de política de renderização adicionados em `test/offline_map_render_policy_test.dart`, ainda não executados sem Flutter.
- `flutter analyze`, `flutter test`, APK Android e testes de uso real de Google Maps/MBTiles/download não realizados no ambiente sem SDK Flutter.
- Os testes de contrato estático não substituem compilação nem uso real em dispositivo.
