# Validação Vigia IA 1.0.361+361

- Base confirmada: ZIP local 1.0.360+360 (`pubspec.yaml`) e arquivo correspondente no Google Drive, conferidos em 06/11/2026. Não eliminar arquivos da base.
- Testes Dart em `test/trip_smart_stages_361_test.dart` para aumento conservador de dias, perfis ausentes, candidatos perto/longe do trajeto e persistência JSON retrocompatível.
- Regressões estruturais Python: `tool/test_smart_trip_stages_361.py`; verificação preventiva total: `tool/verify_project.sh`.
- SDK Flutter/Dart não está instalado neste ambiente; `flutter analyze`, `flutter test` e geração do APK ainda devem ser validados pelo GitHub Actions.
- O modelo não inventa hospedagem, acesso ou elevação e não garante horário de chegada nem autonomia da bicicleta.

## Validação local — 06/11/2026

- `bash tool/verify_project.sh`: **aprovado**, código de saída 0.
- Suíte principal de regressão Python: **522 testes executados, 521 aprovados e 1 ignorado** por ausência do SDK Dart.
- Novos testes estruturais `tool/test_smart_trip_stages_361.py`: **5 aprovados**.
- Sincronização de versão e consistência das notas: aprovadas.
- Flutter Analyze, Flutter Test e compilação Android: **não executados**, dependem do GitHub Actions com o SDK instalado.
