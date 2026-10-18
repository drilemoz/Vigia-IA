# Vigia IA 1.0.292+292

## Buildfix do workflow Android APK 245

O workflow usou a versão 1.0.291 e aprovou 237 testes Python de verificação preventiva. O `flutter analyze --fatal-infos --fatal-warnings` apontou dois avisos Dart: `lib/app/app.dart:122` e `lib/services/data_usage_service.dart:176`, ambos relacionados a `if` sem chaves.

A 1.0.292 acrescenta blocos explícitos nesses dois retornos, sem modificar as respectivas condições. O erro de tipos do scanner RTSP, observado no build 244, não retornou no build 245.

## Preservação

- Modo Transmissor Exclusivo, transmissão com tela apagada, gravação, isolamento dos demais módulos, política térmica e Eco.
- Scanner Wi-Fi híbrido ONVIF/RTSP/MCRP, memória da última câmera e retomada remota.
- Dados persistidos e preferências permanecem no mesmo formato.

## Validação

- 241 testes Python, sincronização de versão, imports e CI: aprovados localmente.
- `tool/verify_project.sh`: execução parcial; limite de 160 segundos interrompeu a verificação integral.
- `flutter analyze`, `flutter test` e APK Android: dependem do SDK/CI, sem afirmar build local.
