# Validação 1.0.330+330

- `tool/verify_project.sh` para contratos atuais e históricos; testes de regressão novos para validação das URLs H.264.
- Conferir que MCRP usa o mesmo pareamento para MJPEG e H.264 sem conversão/decoder duplicado.
- Em aparelho Android: 10 min de H.264 no monitor principal, 10 min de MJPEG, troca de codec duas vezes, IA ligada/desligada, segunda câmera e perda/reconexão do Wi-Fi.
- Em RTSP: verificar H.265 /onvif1 com VLC; verificar câmera sem snapshots para detectar possível falso positivo.
- `flutter analyze`, `flutter test`, `flutter build apk` e testes Android físicos necessários.
