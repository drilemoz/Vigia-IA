# Validação · Vigia IA 1.0.317+317

## Escopo

Teste isolado de stream H.264 RTSP pelo Media3, sem IA. Não substitui LibVLC no Monitorar nem altera MCRP.

## Verificações locais

- `tool/test_media3_rtsp_317.py`: 8 testes estruturais do novo caminho, incluindo cópia espelhada para bootstrap e sanitização de eventos.
- `tool/test_lan_scan_289.py`: 8 testes de descoberta e integridade de MainActivity espelhada.
- Kotlin PSI: MainActivity + Media3RtspPlatformView sem erros sintáticos.
- Versão/catalogo/metadata: `tool/check_release_consistency.py` e `tool/check_version_sync.py` (ambos exigem 1.0.317+317).
- `tool/verify_project.sh`: execução integral finalizada sem erros. Suíte geral `python3 -m unittest discover -s tool -p test_*.py -v`: **323 testes, OK (1 ignorado)**. Os contratos adicionais de IA, MCRP, Câmeras/Ao vivo, navegação, áudio, integridade e pipeline passaram.

## Testes pendentes (não inferir aprovação)

- Flutter `analyze --fatal-infos --fatal-warnings`, testes de widgets e `flutter build apk --release` no GitHub Actions.
- Teste físico de RTSP H.264 com autenticação e SPS/PPS no SDP; observar primeiro frame, erros, pausa/retorno, consumo de CPU/RAM e fechamento.
- Teste com senha contendo caracteres especiais devidamente percent-encoded e com rede Wi-Fi/hotspot.
- Não há capturas RGB para IA nem câmera habilitada automaticamente ao salvar (planejado para versões seguintes).
