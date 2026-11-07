# Vigia IA 1.0.366+366 — Correção do workflow APK 311

- **Diagnóstico real:** o log do GitHub Actions 311 registrou um único aviso fatal em `flutter analyze --fatal-infos --fatal-warnings`: `unnecessary_import`, `lib/services/location_tracking_service.dart:5:8`.
- **Correção:** removido apenas o import direto `package:geolocator_android/geolocator_android.dart` do serviço de localização. O pacote `geolocator` já exporta os elementos usados, conforme o analisador no CI. A dependência `geolocator_android` em `pubspec.yaml` foi mantida.
- **Sem mudança funcional:** permanecem a consulta GPS com `AndroidSettings` em 15 s com mapa visível, o diagnóstico de leituras antigas, os pontos de interesse e os pacotes offline.
- **Prevenção:** novo teste `tool/test_build311_geolocator_import_366.py`, incluído no `tool/verify_project.sh`.
- **Validação:** consulte `VALIDATION-1.0.366.md`. Análise Dart, testes Flutter e compilação APK exigem CI com Flutter instalado.
