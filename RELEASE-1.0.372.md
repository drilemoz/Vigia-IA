# Vigia IA 1.0.372+372 — Buildfix Android APK 317

**Data:** 09/11/2026

## Mudanças

- Correção do lint `curly_braces_in_flow_control_structures` no Planejamento ao descartar uma rota não salva.
- Preserva os avisos de acesso seguro, a navegação por etapas, a preparação offline e o funcionamento existente.
- Nenhum cálculo de rotas ou estrutura persistida foi alterado.

## Validação

- O build 317 passou pela verificação preventiva (561 testes) e foi bloqueado somente na análise estática.
- Teste local estrutural de regressão adicionado; executar novamente `flutter analyze`, `flutter test` e APK no CI para validação completa.
