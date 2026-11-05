# Vigia IA — 1.0.341+341 (2026-11-04)

## Correção do workflow Android APK 297

- Eliminado `undefined_named_parameter` no teste Media3 RTSP: chamada à tela passou a fornecer somente `cameraName`, `url` e `forceTcp`, compatíveis com o construtor existente.
- Substituído `value` por `initialValue` no seletor de transporte RTSP, eliminando aviso de API depreciada no Flutter 3.44.9.
- Preservado o automático UDP/TCP do player LibVLC, memorização por câmera, mapas offline e demais funcionalidades.
- Metadados e Novidades atualizados para 1.0.341+341.

## Validação

- Falha encontrada em `flutter analyze --fatal-infos --fatal-warnings`, após verificação preventiva verde no workflow APK 297.
- `flutter analyze`, `flutter test` e build Android da 1.0.341 pendentes de confirmação no GitHub Actions.
