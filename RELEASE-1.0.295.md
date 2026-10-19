# Vigia IA 1.0.295+295 · Build 248: verificação Flutter

## Diagnóstico
O workflow Android APK 248 confirmou que `flutter analyze` da 1.0.294 não encontrou problemas. A etapa `flutter test` encerrou com dois testes de interface desatualizados. O APK não foi gerado no build 248.

## Ajustes
- `test/main_navigation_bar_test.dart`: passa a exigir cinco destinos sem Ajustes na barra inferior. A tela de configurações permanece acessível no cabeçalho superior direito.
- `test/mcrp_remote_controls_test.dart`: passa a acionar o card Vídeo, escolher resolução 480p e FPS 10, fechar o modal, abrir Lanterna e selecionar modo de 30 segundos. Preserva os testes de zoom, REC, pausa e controles indisponíveis.
- Sem mudança no código de produção de vídeo, descoberta, rede, IA ou gravação.

## Validação e pendências
- Validar `flutter test` no próximo GitHub Actions, pois o SDK Flutter não está disponível localmente.
- `flutter analyze` passou no build 248 para a 1.0.294; o build completo ainda está pendente para a 1.0.295.
