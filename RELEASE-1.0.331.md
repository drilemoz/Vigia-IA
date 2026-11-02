# Vigia IA 1.0.331+331 — Correção do gate MCRP H.264 (APK 277)

## Correção
- Corrigido o verificador `tool/check_mcrp_245.py` (legado) que ainda exigia desligar a IA para H.264, apesar do pipeline H.264 via LibVLC introduzido na 1.0.330.
- Contrato novo verifica que bytes H.264 não entram no parser MJPEG e que quadros para IA vêm do LibVLC por `RtspCameraSource`.
- Acrescentados testes `tool/test_mcrp_codec_gate_331.py` para bloquear regressões em ambas as rotas.

## Preservação
- Nenhuma mudança funcional nos codecs ou na transmissão; mantidos o monitor H.264, MJPEG, IA local, watchdog RTSP, central de seis APIs e recursos de mapas.
- Versionamento público e interno sincronizado para 1.0.331+331.

## Validação
- `tool/verify_project.sh` aprovado localmente (exit 0); 385 testes na suíte agregada, 384 aprovados e 1 ignorado. Ver `VALIDATION-1.0.331.md`.
- `flutter analyze`, `flutter test`, compilação Android e testes em aparelho exigem SDK/CI.
