# Vigia IA 1.0.320+320 · Correção Flutter Analyze do APK 268

## Falha confirmada no GitHub Actions

A versão 1.0.319 passou nos 333 testes Python da verificação preventiva, mas o `flutter analyze --fatal-infos --fatal-warnings` detectou dois avisos que interromperam o build:

1. `lib/services/automatic_diagnostics_service.dart:64:49`: `curly_braces_in_flow_control_structures` no teste de limites da região 3×3 dos toques.
2. `lib/widgets/diagnostic_ui_interaction_capture.dart:1:8`: `unnecessary_import` de `dart:ui` (a classe `PointerDeviceKind` já é importada por `flutter/gestures.dart`).

## Mudanças

- Envolvida a saída antecipada do `if` de coordenadas em `{ return; }`, sem mudar condições ou intervalos.
- Removida apenas a declaração de import redundante; permanece a importação `package:flutter/gestures.dart`.
- Novo teste estrutural `tool/test_build268_flutter_analyze_320.py` conectado ao verificador preventivo.
- Versionamento sequencial 1.0.320+320 e referências sincronizados, com histórico preservado.

## Não alterado

Gravação urgente de toques/menus, recuperação automática de incidentes, proteção de dados sensíveis, câmera RTSP, opção experimental Media3 H.264, MCRP, IA, mapas, GPS, rede e modo de transmissão.

## Próximas verificações

Compilar no GitHub Actions e confirmar `flutter analyze --fatal-infos --fatal-warnings`, `flutter test --coverage` e `assembleRelease`; validação em aparelho físico ainda não realizada.

## Validação local

- 336 testes Python: 335 aprovados e 1 ignorado.
- Regressão direcionada de ambos os lints aprovada e metadados sincronizados.
- Verificação `tool/verify_project.sh` iniciada, mas não concluída no limite local; execução Flutter/Android ainda pendente.
