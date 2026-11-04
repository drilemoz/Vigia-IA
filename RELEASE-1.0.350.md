# Vigia IA 1.0.350+350 — correção do Flutter Analyze no APK 294

## Diagnóstico
- Workflow APK 294 passou a verificação preventiva mas parou em `flutter analyze --fatal-infos --fatal-warnings`, após um único aviso `info` (`curly_braces_in_flow_control_structures`) em `lib/screens/map_monitoring_screen.dart:538`, versão 1.0.349.
- O APK não foi compilado nessa execução.

## Correção
- A guarda que retorna quando o widget não está montado, o aplicativo está inativo ou a bateria não mudou agora possui bloco `{ return; }`.
- `setState` somente ocorre quando há novo dado; captura de erros opcionais, HUD, bússola, GPS, câmera e navegação permanecem inalterados.
- Novo teste preventivo `tool/test_build294_flutter_analyze_350.py` verifica a sintaxe e a presença de seu contrato no script de verificação.
- Metadados, Novidades e dois históricos da tela Sobre sincronizados, com 1.0.349 preservada no histórico.

## Validação
- Veja `VALIDATION-1.0.350.md`. `flutter analyze`, `flutter test` e build Android pendem de execução no GitHub Actions.
