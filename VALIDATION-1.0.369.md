# Validação Vigia IA 1.0.369+369

- Base 1.0.368 verificada no ZIP, repositório GitHub e Drive.
- Caso observado: tela 1.0.367+367 declara "atualizado", mas GitHub publica v1.0.368+368.
- Correção: `VigiaGitHubReleasePolicy.newest` não depende de APK universal aprovado para indicar versão superior.
- Filtros de origem, hash, pacote, assinatura e confirmação de instalação preservados.
- Compilação Flutter e testes em dispositivo pendentes de CI.

## Resultado local em 07/11/2026

- `tool/verify_project.sh`: finalizado com sucesso; 556 testes Python (555 aprovados, 1 ignorado), verificações estruturais e de contratos complementares aprovadas.
- Testes específicos do atualizador, do limite do APK e das versões anteriores: 12 aprovados.
- `tool/check_version_sync.py`, `tool/check_release_consistency.py` e `tool/check_latest_baseline.py`: aprovados.
- Não foi possível consultar o JSON ao vivo da GitHub Releases API neste ambiente. A captura enviada comprova a divergência da tela, mas não informa qual filtro de asset excluiu a Release.
- `flutter analyze`, `flutter test`, compilação Android e testes em aparelho: não executados aqui por ausência de Flutter/Dart SDK. Necessário executar GitHub Actions.
