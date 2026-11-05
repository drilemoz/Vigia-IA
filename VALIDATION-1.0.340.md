# Verificação 1.0.340+340 — APK 296

## Origem e correção

- Arquivo de diagnóstico: `Vigia-IA-Android-APK-296-logs.zip`, etapa `build/10_Verificacao preventiva.txt`.
- Falha original: `test_reject_old_release_or_empty_news` em `tool/test_news_catalog_policy_301.py` esperava mensagem de mapas offline que já não existia na versão 1.0.339; o `replace` não alterava o catálogo e o teste não recebia a exceção esperada.
- Correção: teste descobre a versão pelo `pubspec.yaml`, altera a primeira mensagem real do catálogo e confirma falha para versão divergente, mensagem vazia, `TODO` e `placeholder`.
- O validador `tool/check_news_catalog_policy.py` agora também rejeita uma mensagem vazia no meio de outras mensagens válidas.
- O teste `tool/test_release_consistency_296.py` deixou de exigir `versionCode` antigo (338) e passou a simular um manifesto Android propositalmente divergente.
- Corrigida documentação e catálogo de versão 1.0.340; mantido o RTSP automático UDP/TCP e os mapas offline anteriores.

## Verificações executadas

- `python3 -m unittest discover -s tool -p 'test_*.py' -q`: **434 testes, 433 aprovados e 1 ignorado**; saída 0.
- `bash tool/verify_project.sh`: **aprovado, saída 0**; inclui a suíte agregada de 434 testes e verificações preventivas adicionais.
- `python3 tool/check_version_sync.py`: aprovado; `1.0.340+340` sincronizado.
- `python3 tool/check_release_consistency.py`: aprovado; build e versão consistentes.
- `python3 -m unittest -q tool/test_news_catalog_policy_301.py tool/test_release_consistency_296.py`: seis testes aprovados.
- Flutter SDK ausente: **não executados** `flutter analyze`, `flutter test` ou `flutter build apk`.
- Teste no dispositivo real e RTSP UDP/TCP permanece pendente.

## Próximo passo

Executar novo workflow Android do GitHub Actions. O build APK 296 parou antes do analisador Flutter; não há evidência nele de falhas de compilação nem aprovação da compilação.
