# Validação do Vigia IA 1.0.341+341 — APK 297

## Diagnóstico

Arquivo recebido: `Vigia-IA-Android-APK-297-logs.zip`. Verificação preventiva aprovada com 434 testes Python; a etapa `flutter analyze --fatal-infos --fatal-warnings` falhou por `undefined_named_parameter` na tela `multi_camera_screen.dart:440` (`transport:` na invocação de `Media3RtspTestScreen`) e por `deprecated_member_use` em `rtsp_camera_editor_dialog.dart:476` (`DropdownButtonFormField.value`).

## Correção

- Retirado somente `transport:` da prévia Media3, que aceita `forceTcp` e continua independente da lógica LibVLC de fallback TCP/UDP.
- `DropdownButtonFormField.initialValue` substitui o membro obsoleto.
- Novo teste estrutural cobre assinatura do construtor Media3 e chamada RTSP. Versionamento e metadados sincronizados.

## Resultados e pendências

- `bash tool/verify_project.sh`: **aprovado (exit 0)**.
- Suíte Python integrada ao verificador: **437 testes executados, 436 aprovados e 1 ignorado** (Dart SDK ausente).
- Testes direcionados para compatibilidade Media3/RTSP, política de transporte, Novidades e versão: **15 aprovados**, e execução adicional do teste de planejamento/versionamento: 13 aprovados.
- `python3 tool/check_version_sync.py` e `python3 tool/check_release_consistency.py`: aprovados para `1.0.341+341`.
- Na comparação com a 1.0.340: 0 arquivos removidos, 3 adicionados e 63 arquivos atualizados (principalmente versão e contratos).
- Flutter SDK indisponível no ambiente: `flutter analyze`, `flutter test`, `flutter build apk` e teste físico pendentes.
