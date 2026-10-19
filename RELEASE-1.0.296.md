# Vigia IA 1.0.296+296 · Correção do build 249

O workflow APK 249 (código 1.0.295) reconheceu a versão, mas parou na Verificação preventiva antes de iniciar o Flutter Analyzer. O contrato `tool/verify_project.sh` verificava incorretamente build 294 no catálogo da 1.0.295. O código de Novidades tinha corretamente build 295.

## Correções
- Novo `tool/check_release_consistency.py`, com versão obtida dinamicamente do pubspec e checagem de metadados, novidades (duas ocorrências), Sobre, release e versão Android.
- `tool/verify_project.sh` utiliza a nova checagem antes de executar verificações antigas, evitando lints/compilações demoradas quando a versão estiver inconsistente.
- Testes novos simulam o erro de catálogo e confirmam metadados da versão.
- Atualizados README, CHANGELOG, arquitetura, Sobre, notas, build e metadados para 1.0.296+296.

Nenhuma lógica de vídeo/REC, IA, descoberta LAN/RTSP, economia, navegação ou sensores foi modificada.

## Pendente
Compilar no GitHub Actions: análise Dart, testes Flutter, Kotlin/Gradle e APK não executados localmente.
