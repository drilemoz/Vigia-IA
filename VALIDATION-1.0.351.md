# Validação 1.0.351+351 — recuperação da linha correta

## Base e integridade

- Última versão encontrada nos ZIPs locais e na pasta `Meu Drive/Projetos/Vigia IA/` (consulta em 05/11/2026): **1.0.350+350**, `Vigia-IA-v1.0.350-APK294-Flutter-Analyze-Corrigido.zip`.
- SHA-256 do ZIP original de base: `5348bc502a12871eba1a27fa0e773976768abba71f73d56d6f0754fd4ed8dbc9`.
- **1.291/1.291 arquivos do ZIP de base mantidos na árvore final. Nenhum nome de arquivo excluído.**
- Comparação com a linha paralela 1.0.341: 43 arquivos da 1.0.350 ausentes naquela variante, recuperados com a base correta.
- Arquivos de mapas/MBTiles, planejador, economia de GPS/HUD/bússola e diagnóstico/Android oriundos da 1.0.350 preservados; apenas a integração RTSP foi trazida da linha antiga.

## Testes executados

- `tool/check_version_sync.py`: aprovado (1.0.351+351).
- `tool/check_latest_baseline.py`: aprovado (base 1.0.350+350, nova 1.0.351+351).
- `tool/check_release_consistency.py`, `tool/check_news_catalog_policy.py`, `tool/check_import_targets.py`, `tool/check_ci_contract.py`: aprovados.
- `python -m unittest -q tool.test_rtsp_auto_transport_339 tool.test_restore_350_rtsp_351`: **8 testes aprovados**.
- `tool/verify_project.sh`: **exit 0**; suíte agregada com **479 testes Python, 478 aprovados e 1 ignorado**. Os demais contratos do verificador, incluindo câmeras, IA e mapas, passaram.
- ZIP final: conferir CRC, contagem e arquivos no empacotamento.

## Pendências e limites

- `flutter analyze`, `flutter test`, build Android e teste físico com câmera RTSP continuam **pendentes**: Flutter/Dart/Android SDK não instalados localmente.
- A preferência de transporte é memorizada após snapshot VLC; um vídeo que apareça na tela sem snapshot válido pode ser classificado como ainda sem quadro.
- Media3 é uma prévia experimental e usa `forceTcp`; o fallback e a memorização de transporte pertencem ao player LibVLC.
- Não houve upload ao Google Drive; ele foi consultado apenas para localizar a base mais recente.
