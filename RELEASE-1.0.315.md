# Vigia IA 1.0.315+315 — Correção da análise estática do APK 263

## Falha comprovada

O workflow "Android APK 263" com a fonte 1.0.314+314 encerrou em `flutter analyze --fatal-infos --fatal-warnings`, com três infos:

1. `unnecessary_import`: import `dart:typed_data` redundante em `lib/services/automatic_diagnostics_service.dart`.
2. `avoid_relative_lib_imports`: import relativo em `tool/dart/diagnostic_redactor_test.dart`.
3. `avoid_print`: teste de sanitização usando `print` no mesmo arquivo.

O workflow não chegou aos testes Flutter nem à compilação do APK. O aviso Node.js 20 e a ausência de `coverage/lcov.info` durante o pós-job não são a causa raiz.

## Correções

- Retirado somente o import redundante do serviço; `Uint8List` segue fornecido pela dependência `package:flutter/services.dart` já importada.
- Teste Dart muda para `package:vigiaia/utils/diagnostic_redactor.dart` e `stdout.writeln` com `dart:io`, preservando todas as verificações de segredo.
- Adicionado teste regressivo que impede reintrodução dos três padrões, vinculado à verificação preventiva.
- Versionamento 1.0.315+315 sincronizado (app, Android gerenciado pelo Flutter, documentação, verificador, Novidades e Mudanças).

## Preservado

Sem mudanças no comportamento de diagnóstico automático, modelos IA, RTSP, gravação MP4/H.264, câmeras, navegação, GPS, mapa offline, transmissão ou integração ESP32. A versão é um buildfix da 1.0.314.

## Validação

Ver `VALIDATION-1.0.315.md`. Compilação real, análise Flutter e testes Flutter requerem execução no GitHub Actions, por indisponibilidade do SDK local.
