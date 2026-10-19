# Vigia IA 1.0.310+310

## Correção do workflow Android APK 260

- `flutter analyze` passou sem apontamentos; 579 testes Flutter passaram.
- APK Release parou na tarefa `:app:minifyReleaseWithR8`, ao procurar oito classes opcionais de reconhecimento de texto chinês, devanágari, japonês e coreano usadas apenas por branches opcionais do plugin ML Kit.
- Regras exatas `-dontwarn` adicionadas em `android/app/proguard-rules.pro` e `tool/android/proguard-rules.pro`, e configuradas na release do Gradle e no bootstrap Android, sem desativar R8 ou acrescentar os modelos ausentes.
- OCR Latin, Galeria Remota, fotos automáticas no A3, gravação e todo o comportamento anterior mantidos.
- APK Release ainda depende de validação no próximo GitHub Actions; não afirmar build bem-sucedido localmente.
