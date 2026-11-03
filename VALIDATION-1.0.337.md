# Vigia IA 1.0.337+337 — Verificações

- Base: `1.0.336+336`; alteração concentrada no fluxo de navegação, sem modificar armazenamento das chaves, câmeras, backup nem mapas offline.
- **421 testes Python de regressão** executados: **420 aprovados, 1 ignorado** (Dart SDK ausente). Inclui oito testes novos em `tool/test_navigation_ptbr_compact_337.py`.
- `tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovados para `1.0.337+337`.
- **`bash tool/verify_project.sh`: aprovado (exit 0)** na execução integral final, com contratos das câmeras, IA, mapas, rotas, áudio, APIs e versionamento. Testes antigos atualizados para o idioma `pt-BR`, painel inicialmente compacto e ocultação de cartões sem dados.
- Novo teste Dart `test/map_navigation_instruction_ptbr_test.dart` cobre tradução de manobras; **não executado** localmente.
- Não disponível localmente: Flutter SDK / Dart / Android SDK. **Pendentes no GitHub Actions**: `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, build do APK e validação física da interface/GPS/TTS/Google Maps.
- Nenhuma solicitação com chaves reais, navegação física nem teste de mapa no dispositivo foi executado.
