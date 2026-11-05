# Validação — Vigia IA 1.0.352+352

**Base:** `Vigia-IA-v1.0.351-Base350-RTSP-Integrado.zip`, última fonte disponível no diretório (verificada em 05/11/2026); pasta Google Drive `Projetos/Vigia IA` tinha 1.0.350, portanto não superava a base local.

## Resultados concluídos

- 31 testes Python de API/backup Google Maps, RTSP, restauração base 350 e versionamento: **31 aprovados**.
- `python3 tool/check_version_sync.py`: **aprovado**.
- `python3 tool/check_latest_baseline.py`: **aprovado**, 1.0.351 -> 1.0.352.
- `python3 tool/check_release_consistency.py`: **aprovado**.
- `python3 tool/check_import_targets.py`: **aprovado**, verificação parcial de destinos de imports.
- Comparação ZIP base: 1.299/1.299 arquivos de fonte preservados; nenhuma exclusão.
- ZIP final: integridade CRC verificada após empacotamento.

## Limitações / pendências

- `tool/verify_project.sh`: excedeu o limite de execução disponível, sem falha reportada nas etapas alcançadas; **não foi concluído**.
- `python3 -m unittest discover -s tool -p 'test_*.py'`: excedeu o limite de execução; **não foi concluído**.
- SDK Dart/Flutter não instalado: **não foram executados** `flutter analyze`, `flutter test` nem o build Android.
- Fluxo real de permissões de Storage Access Framework, salvamento do `.env`, importação nativa e layout em dispositivos físicos: pendentes do teste APK no GitHub Actions/aparelho.

## Política dos dados

- A exportação normal da central grava `.env` em **texto puro**, deliberadamente sem senha/criptografia; a importação `.env` valida os campos antes de gravar e exige confirmação das substituições.
- O Android Keystore permanece para **armazenamento no aparelho**. Chave Google Maps incorporada ao APK não é exportada.
- Importação dos backups criptografados antigos `.vigiaapis` preservada.
