# Validação — Vigia IA 1.0.331+331 (APK 277)

## Diagnóstico
- Fonte: workflow “Vigia IA Android APK 277”, pacote de logs enviado pelo usuário.
- Falha original na etapa preventiva: `test_mcrp_245.TestMcrp245.test_structural_contracts`, exigindo `onChanged: codec == 'h264' ? null` na tela MCRP.
- Essa condição ficou obsoleta na versão 1.0.330, que passou a permitir IA local sobre snapshots H.264 por LibVLC.

## Correção
- O contrato `tool/check_mcrp_245.py` verifica agora que o parser MJPEG só lê MJPEG, enquanto a fonte H.264 usa `RtspCameraSource`/LibVLC (`:demux=h264`) e encaminha quadros RGB ao receptor da IA.
- O novo arquivo `tool/test_mcrp_codec_gate_331.py` protege explicitamente ambos os caminhos.
- Todas as referências da versão corrente e os metadados foram sincronizados para 1.0.331+331.
- Sem alterações funcionais na reprodução, detecção ou decodificação; configurações e outros módulos preservados.

## Execuções locais
- `python3 -m unittest -q tool/test_mcrp_codec_gate_331.py tool/test_mcrp_h264_330.py tool/test_mcrp_245.py`: 14/14 testes aprovados.
- `python3 tool/check_mcrp_245.py`: 22 contratos aprovados.
- `python3 tool/check_version_sync.py`: aprovado; versão 1.0.331+331.
- `python3 tool/check_release_consistency.py`: aprovado.
- `bash ./tool/verify_project.sh`: **aprovado (exit 0)**. Suíte agregada de 385 testes Python: 384 aprovados e 1 ignorado; demais contratos preventivos também aprovados. Execução local registrada no log desta sessão.

## Limitações
- Flutter SDK não está disponível neste ambiente. `flutter analyze`, `flutter test`, `flutter build apk` e testes de transmissão reais não foram executados; dependem do workflow GitHub Actions e de aparelhos Android.
- O sucesso dos testes estáticos não comprova reprodução H.264, snapshots ou inferência reais.
