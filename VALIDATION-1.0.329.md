# Validação 1.0.329+329

## Fonte
- Testes Python: `tool/verify_project.sh`.
- Regressão do orçamento de tentativas: `test/rtsp_recovery_policy_test.dart` (exige Flutter).
- Validação `pubspec`, `app_metadata`, `app_identity`, `github-manager`, `Novidades` e interface Sobre.

## Pendente em hardware
- Teste com RTSP TCP em H.265 (`/onvif1`), continuidade por 10 minutos.
- Quedas de Wi-Fi e recuperação até três vezes, sem loop infinito.
- Tela de Media3 isolada e sem interferência com VLC/IA; dois celulares com desempenhos diferentes.
- Flutter analyze, flutter test e APK por CI.
