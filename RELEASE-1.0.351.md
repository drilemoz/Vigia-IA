# Vigia IA 1.0.351+351 — restauração da linha mais recente + RTSP automático

**Base:** `Vigia-IA-v1.0.350-APK294-Flutter-Analyze-Corrigido.zip`, localizado e confirmado tanto no diretório local quanto na pasta do projeto no Google Drive em 05/11/2026. A linha 1.0.341 alternativa não substitui a 1.0.350.

## Mudanças

- Preservados integralmente os arquivos já existentes na 1.0.350, especialmente mapas offline (provedor MBTiles retido), GPS/HUD/bússola com economia de energia, planejador de cicloviagem e diagnósticos.
- Integrada ao **LibVLC** a política RTSP Automático (último transporte com primeiro quadro confirmado ou UDP inicial; tenta TCP/UDP alternativo sem primeiro quadro). Mantidas opções manuais TCP/UDP e compatibilidade de câmeras cadastradas antes da mudança, respeitando `rtspForceTcp`.
- Persistência do modo RTSP nas configurações e propagação para monitor principal, câmera secundária, multi-câmera e PiPs do mapa.
- Media3 experimental conserva a assinatura de `forceTcp` e não recebe argumento `transport` inexistente. Dropdown de transporte usa `initialValue`.
- Preferência de transporte memorizada apenas após captura real de um quadro e vinculada a hash SHA-256 da URL. Sem URL/senha em logs.
- Regra de verificação da base mais recente acrescentada ao `AGENTS.md` para evitar repetição de regressões por versões paralelas.

## Limites

- Confirmação de primeiro quadro usa snapshots do VLC; falha de snapshot não prova indisponibilidade do vídeo.
- Não houve teste com câmera RTSP real nem compilação Flutter/Android neste ambiente. Ver `VALIDATION-1.0.351.md` para resultados efetivos.
