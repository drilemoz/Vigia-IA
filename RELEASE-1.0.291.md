# Vigia IA 1.0.291+291

## Correção do workflow Android APK 244

O `flutter analyze --fatal-infos --fatal-warnings` encontrou três problemas na 1.0.290: dois `if` sem chaves, nos arquivos `lib/app/app.dart` e `lib/services/data_usage_service.dart`, e um tipo incorreto de decoder Latin-1 no scanner LAN.

A nova versão acrescenta blocos explícitos e converte cada bloco `Uint8List` recebido em string com `latin1.decode`, preservando a sequência RTSP OPTIONS, limites de rede, timeout e autenticação MCRP.

## Compatibilidade

- Transmissor Exclusivo com tela apagada, isolamento, controle remoto e proteção térmica preservados.
- Scanner híbrido Wi-Fi/ONVIF/RTSP sem alterações nas portas, tokens, gravação ou preferências.
- Metadados, documentação, Sobre e tela Novidades sincronizados com a nova versão.

## Validação

- `tool/verify_project.sh`: execução parcial no ambiente local, interrompida pelo limite de execução; testes direcionados e 237 testes Python aprovados.
- `flutter analyze`, `flutter test` e build Android: dependem do ambiente com Flutter SDK/GitHub Actions; sem afirmação de compilação local.
