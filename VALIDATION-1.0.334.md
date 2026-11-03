# Validação 1.0.334+334

- Autenticidade dos backups: AES-256-GCM com AAD e salt único; arquivo importado de no máximo 64 KiB, JSON autenticado e provedores em lista permitida.
- Sem chaves em arquivos de logs/Drive/GitHub. Google Maps do manifesto e Open-Meteo não exportados.
- Busca local e limite de resposta online, remoção do cabeçalho redundante e atalho Explorar em faixa única: validação de fonte, aguardando teste visual em aparelho.
- `flutter analyze`, `flutter test`, Android Keystore/SAF e APK aguardam execução GitHub Actions.

## Execução local

- `python -m unittest discover -s tool -p 'test_*.py' -q`: 399 testes, 398 aprovados, 1 ignorado.
- `bash tool/verify_project.sh`: concluído com exit 0, incluindo contratos complementares.
- Kotlin/JVM: rodada real de cifragem/decifragem AES-256-GCM extraída de `MainActivity.kt`, senha correta aprovada, senha incorreta e bytes adulterados rejeitados.
- `python tool/check_version_sync.py` e `python tool/check_release_consistency.py`: aprovados.
- `flutter analyze`, `flutter test`, build Android e teste visual de layout/Saf/Keystore em aparelho: **não executados** por ausência de SDK Flutter/Android.
