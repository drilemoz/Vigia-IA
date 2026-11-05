# Vigia IA 1.0.340+340 — Correção do workflow APK 285

- Base: 1.0.339+339. O build 285 parou na etapa Verificação preventiva, com `AssertionError: ValueError not raised` em `test_news_catalog_policy_301.py`, antes da compilação Android.
- Causa: teste procurava uma frase desatualizada do catálogo; a substituição não acontecia, mas esperava-se que o validador rejeitasse `TODO`.
- Solução: testes usam a primeira mensagem real do catálogo e a versão atual do `pubspec.yaml`; verificam que a alteração ocorre. O validador reconhece mensagens vazias e as rejeita.
- Gates antigos de `tool/verify_project.sh` que exigiam `AndroidPlatformViewMode.hc` e `AnimatedOpacity` atualizados para verificar TLHC com fallback HC, TextureView e montagem 3D sem opacidade zero.
- Mantidas as funcionalidades e mitigações de MBTiles/MapLibre da 1.0.339, sem reivindicar resolução do ANR/PlatformView sem teste de aparelho.
- Atualizados versão/build 1.0.340+340, tela Sobre, Novidades, documentação e contratos de versionamento.
- `tool/verify_project.sh`: aprovado (exit 0); 436 testes Python agregados (435 aprovados, 1 ignorado).
- Pendências: Flutter analyze, Flutter test, compilação APK e validação no Xiaomi Android 13.
