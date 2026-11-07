# Vigia IA 1.0.364+364 — Correção do workflow APK 309

- Corrigido `invalid_null_aware_operator` em `trip_planning_screen.dart:2096` durante a exibição da nota offline de uma parada conferida.
- O registro já está comprovadamente não nulo pela condição que envolve `savedCheck!`; eliminada apenas a sintaxe nula redundante em sua interpolação.
- Preservados Planejamento, pacote MBTiles, pacotes de POIs, viagens salvas, confirmações de parada e funcionamento offline.
- Teste de regressão do lint e sincronização de versão, Novidades, Sobre, documentos e identificadores do app.
- A compilação Flutter/Android deve ser validada pelo próximo workflow.
