# Vigia IA 1.0.318+318 · Correção de build 266

Base: 1.0.317+317. Alteração pontual para recuperar a compilação da primeira integração Media3 RTSP.

## Causa confirmada nos logs

- `flutter analyze --fatal-infos --fatal-warnings` falhou em `lib/screens/multi_camera_screen.dart:429:40` com `argument_type_not_assignable`.
- `CameraEndpoint.address` é `String?`, enquanto o `url` exigido pelo `Media3RtspTestScreen` é `String`.
- 323 testes Python de prevenção passaram no workflow 266 antes do analisador; build APK nem testes Flutter foram iniciados.

## Correção

- Ação de prévia Media3 só existe para `CameraEndpointType.rtsp` com endereço presente e não vazio.
- Variável local final `rtspTestUrl` promove o tipo para `String` sob guarda, evitando `!` ou URL artificial.
- Teste de regressão em `tool/test_build266_media3_nullable_318.py` e sincronização de todas as referências da versão.
- Mantém reprodução Media3 de teste sem IA; VLC no Monitorar, MCRP, mapas e gravações não foram alterados.

## Limites

- Flutter analyze/test, compilação Gradle/Android e reprodução em aparelho requerem CI/aparelho; validação Python não substitui essas etapas.
- Cadastro com verificação real antes de salvar e descoberta automática de celulares continuam planejados para futuras versões.
- Nenhuma credencial ou chave de assinatura foi adicionada.
