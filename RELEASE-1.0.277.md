# Vigia IA 1.0.277+277

## Ajuste de análise estática do transmissor nativo

- O APK 230 passou nos testes preventivos, mas parou na análise Flutter por `invalid_null_aware_operator` em `native_transmitter_screen.dart:203`.
- Eliminado o acesso `s?.ready != true` desnecessário após a promoção da variável de status; consulta agora `!s.ready`, mantendo a indicação de espera por quadros.
- Adicionado teste de regressão ao verificador preventivo, preservando o motor Kotlin, QR privado e a gravação MCRP pelo Ao vivo.
- Versão e metadados Android atualizados para 1.0.277+277.

## Verificação

- `tool/verify_project.sh` aprovado, incluindo 167 testes Python na suíte preventiva principal e demais contratos estruturais.
- A análise Flutter e a compilação Android completas ainda dependem de GitHub Actions.
