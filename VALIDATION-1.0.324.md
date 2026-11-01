# Validação Vigia IA 1.0.324+324

## Âmbito

- Correção do fluxo de busca de cidades do Planejamento e de seu filtro de municípios.
- Compactação do assistente, mapa full-bleed com HUD reposicionado, revisão de prévia e indicadores.
- Normalização de exibição de minutos.

## Testes

- Suíte Python local: 355 testes executados, 354 aprovados, 1 ignorado e 0 falhas.
- `tool/verify_project.sh`: passou com Kotlin fora do PATH.
- `tool/check_version_sync.py`: aprovado.
- Integridade do pacote ZIP: CRC e listagem completas após empacotar.
- Flutter Analyze/Flutter Test/Gradle Android: **não executados localmente**, devem rodar no GitHub Actions.
- Busca online real e navegação GPS em aparelho: **não verificadas**.
