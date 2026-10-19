# Vigia IA 1.0.300+300 · Build 251 corrigido

- Corrigida a verificação preventiva do APK 251: teste histórico fixado em `1.0.296+296` agora deriva a versão vigente do `pubspec.yaml` e confere o catálogo de Novidades.
- No transmissor, o estado `ready` é capturado antes das promoções de nulidade de Dart e reutilizado no bloqueio dos controles, removendo o `s?.ready` redundante que disparava o teste preventivo.
- Novos testes de regressão para ambas as falhas, mantendo a proteção original contra acesso inseguro ao status.
- Não alterados RTSP, autenticação, decodificador, gravação ou protocolo MCRP nesta correção.
- Workflow APK 251 parou em testes Python; `flutter analyze`, `flutter test` e build Android não chegaram a executar.
