# Validação · Vigia IA 1.0.318+318

## Evidência do workflow 266 (1.0.317+317)

- O `Vigia-IA-Android-APK-266-logs.zip` comprova falha de `flutter analyze --fatal-infos --fatal-warnings` em `lib/screens/multi_camera_screen.dart:429:40`: `String?` passado ao `url: String` de `Media3RtspTestScreen`.
- A verificação preventiva no CI anterior aprovou 323 testes Python. Não houve etapa de `flutter test` nem compilação APK nesse build.

## Correção e prevenção

- Endpoint RTSP guarda o endereço opcional numa variável local (`rtspTestUrl`), valida valor não nulo/não vazio e somente então oferece o teste Media3; não há `!` nem URL inventada.
- O teste `tool/test_build266_media3_nullable_318.py` valida o contrato anulável do cadastro e a guarda de URL exigida pelo Media3.
- Metadados, `Novidades`, `Sobre`, changelog, README, notas de release e verificações de versão atualizados para 1.0.318+318.
- Os arquivos Kotlin, espelhos do bootstrap Android, protocolos LAN, VLC, IA, MCRP e mapas não foram modificados.

## Verificações realizadas

- `tool/check_version_sync.py`: aprovado.
- `tool/check_release_consistency.py`: aprovado.
- `python3 -m unittest -v tool/test_build266_media3_nullable_318.py tool/test_media3_rtsp_317.py`: 12 testes aprovados.
- `python3 -m unittest discover -s tool -p 'test_*.py' -q` com Kotlin fora do PATH: **327 testes, 323 aprovados e 4 ignorados**.
- `bash tool/verify_project.sh` com Kotlin fora do PATH: **aprovado**, incluindo 327 testes da suíte geral (4 ignorados) e verificações adicionais.
- A tentativa do verificador com Kotlin disponível ficou presa num teste Kotlin/JVM do transmissor e foi interrompida pelo limite do ambiente. A execução sem Kotlin não valida compilação nativa nem comportamento Kotlin.

## Pendente

- `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, compilação Gradle/Android e teste em aparelho físico com fluxo RTSP H.264; SDK Flutter/Android indisponível localmente.
- A versão 1.0.318 é correção do build 266, **não** implementa prévia obrigatória ao cadastrar câmera. Esse objetivo passa ao próximo marco, 1.0.319 ou posterior conforme logs.
