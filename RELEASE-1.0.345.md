# Vigia IA 1.0.345+345 — Diagnóstico confiável após reabertura

## Correções

- Correlaciona o histórico de saída do Android com a sessão original, usando PID e horário salvo para não atribuir incidentes de outro processo.
- Informa a versão que sofreu o incidente, sem apresentá-la como se fosse uma falha nova da versão instalada.
- Diferencia erro Java/nativo e ANR de encerramento por memória em segundo plano; não inventa motivos quando o Android reporta somente SIGKILL.
- Repete de forma limitada a leitura do diagnóstico quando a inicialização nativa ainda não terminou, e reconsulta quando o app volta ao primeiro plano.
- Mantém relatórios locais e o fluxo de exportar ou adiar; evita mostrar o mesmo aviso repetidamente na mesma execução.

## Limites

- Android pode não registrar o motivo de toda saída, especialmente em aparelhos específicos e versões anteriores à API 30.
- Encerramentos normais e pelo usuário não são falhas; não devem gerar alertas falsos.
- Testes Dart/Flutter e APK físico ainda dependem de GitHub Actions.
