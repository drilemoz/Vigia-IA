# Vigia IA 1.0.353+353 — correção do APK #300

**Base:** código completo 1.0.352+352 (`Vigia-IA-v1.0.352-APIs-Chaves-ENV-Sem-Criptografia.zip`), verificado no diretório local; Google Drive consultado em 05/11/2026 (última cópia 1.0.350).

## Correções

- `tool/verify_project.sh` não exige mais um número de versão antigo: utiliza `pubspec.yaml` para checar as referências atuais.
- Testes de regressão de metadados e Novidades sincronizados para 1.0.353+353.
- Central de APIs/chaves, exportação `.env`, Google Maps, RTSP UDP/TCP, MBTiles e cicloviagem preservados.

## Validação

Consultar `VALIDATION-1.0.353.md`. `flutter analyze`, testes Flutter e compilação Android devem ser confirmados pelo workflow.
