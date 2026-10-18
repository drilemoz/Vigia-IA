# Vigia IA 1.0.274+274

## Correção do workflow Android APK 227

- Corrigidos dois erros Dart `unchecked_use_of_nullable_value`: o estado `recording` do transmissor nativo é lido de maneira segura como `s?.recording == true`.
- Corrigido `curly_braces_in_flow_control_structures` na tela de transmissão Flutter, acrescentando as chaves do `if (mounted)`.
- Integração nativa MCRP v1, modo transmissor Flutter anterior e controles do receptor preservados.
- Todos os metadados, novidades, histórico de mudanças e verificações de versão atualizados para 1.0.274+274.

## Limitações

- O APK 227 parou em `flutter analyze`, antes do build Android. Esta correção é baseada nos três diagnósticos reais; outros problemas no Gradle/Kotlin ainda podem surgir.
- Flutter/Android SDK indisponíveis neste executor local: análise completa, testes Flutter, Gradle e teste físico no Redmi A3 dependem do GitHub Actions e do aparelho.
