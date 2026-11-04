# Verificações — Vigia IA 1.0.340+340

- Base: 1.0.339+339; analisados os logs do workflow Android APK 285 de 2026-11-04.
- Falha reproduzida localmente em `tool/test_news_catalog_policy_301.py`: teste usava texto da versão 1.0.338, não mais presente no catálogo 1.0.339. A substituição falhava silenciosamente e a expectativa de `ValueError` não era satisfeita.
- Correção: fixture obtém a versão e a primeira mensagem do catálogo realmente versionado; injeta `TODO`, mensagem vazia e build anterior, verificando que sejam rejeitados. O validador agora captura strings vazias no array de novidades e rejeita a entrada em vez de ignorá-la.
- Três verificações obsoletas em `tool/verify_project.sh` foram atualizadas para validar TLHC com fallback HC, TextureView e ausência de opacidade inicial zero.
- Preservadas as melhorias da versão 1.0.339 em mapas offline, MBTiles e MapLibre Android; a falha 285 foi pré-compilação e não permite inferir erros ou aprovação da etapa Flutter/Gradle.
- Verificadores de sincronização de versão e consistência do release: aprovados.
- `bash tool/verify_project.sh`: **aprovado (exit 0)**. A suíte agregada executou **436 testes Python (435 aprovados, 1 ignorado)**; os demais contratos e verificadores também terminaram sem falhas.
- `flutter analyze`, `flutter test`, APK Android e testes reais no aparelho: pendentes (SDK Flutter indisponível no ambiente local).
