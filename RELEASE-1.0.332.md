# Vigia IA 1.0.332+332 — Correção do Flutter Analyze (APK 278)

## Diagnóstico confirmado nos logs
- Workflow Android APK 278 da versão 1.0.331+331.
- A verificação preventiva concluiu com sucesso: 385 testes Python aprovados; os 22 contratos do MCRP também passaram.
- `flutter analyze --fatal-infos --fatal-warnings` terminou com código 1 devido a `info • curly_braces_in_flow_control_structures` em `lib/sources/rtsp_camera_source.dart:281`.
- A compilação Flutter/Android não foi iniciada neste workflow.

## Correção
- Em `_scheduleReconnect`, o retorno antecipado após a guarda agora está entre `{}`. A condição e o efeito funcional são os mesmos da 1.0.331.
- Adicionado teste automatizado `tool/test_build278_rtsp_lint_332.py`, executado na verificação preventiva, garantindo que a guarda permaneça entre chaves.
- Incrementada a versão pública e o build para 1.0.332+332, com Novidades, Sobre, README, changelog e verificadores sincronizados.

## Validação executada
- Suíte Python: 387 casos, 386 aprovados, 1 ignorado.
- `tool/verify_project.sh`: aprovado com exit 0.

## Preservação e testes pendentes
- Nenhum comportamento de reconexão, VLC, H.264, MJPEG, MCRP, mapas, IA ou APIs foi alterado.
- `flutter analyze`, `flutter test` e geração de APK precisam ser executados no GitHub Actions (Flutter SDK não disponível neste ambiente).
