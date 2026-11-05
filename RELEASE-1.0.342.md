# Vigia IA 1.0.342+342 — Correção do bloqueio APK 287

## Correção

- O workflow `Vigia IA Android APK 287` interrompia a verificação preventiva porque `test/app_metadata_test.dart` ainda exigia versão 1.0.340/build 340, apesar de o pacote estar em 1.0.341+341.
- O teste Dart agora lê a versão e o build do `pubspec.yaml` e os confronta com `AppMetadata` para não precisar alterar expectativas numéricas manualmente em cada release.
- O validador de versão em Python, contratos preventivos, release, documentação e metadados foram sincronizados para 1.0.342+342.
- Contratos de almoço manual e de acesso às vias agora acompanham o editor compartilhado; ambos os históricos da tela Sobre estão atualizados, preservando versões anteriores.

## Escopo preservado

O editor único de cicloviagem de 1.0.341, biblioteca de viagens, rotas antigas, mapa offline, MapLibre 3D, IA e câmeras continuam sem alteração funcional nesta correção.

## Validação

Consultar `VALIDATION-1.0.342.md`. O código-fonte não contém APK compilado; verificar `flutter analyze`, `flutter test` e `assemble` no GitHub Actions.
