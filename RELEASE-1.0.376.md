# Vigia IA 1.0.376+376 — Correção dos builds 320 e 321

**Data:** 09/11/2026

## Correção

- Retirado operador de asserção de não nulo redundante do planejador de ciclovia. O analisador Dart do CI recusava o aviso `unnecessary_non_null_assertion` com `--fatal-warnings`.
- Nenhuma mudança nos cálculos de rota, tempo, metas em quilômetros, mapas, datas, interface, persistência ou configurações da viagem.
- Incluído teste preventivo para o caso específico.

## Validação

Os scripts Python e a integridade ZIP são verificados localmente. `flutter analyze`, testes Flutter e compilação APK aguardam nova execução pelo GitHub Actions.
