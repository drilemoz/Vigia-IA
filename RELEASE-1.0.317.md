# Vigia IA 1.0.317+317 · Piloto RTSP Media3

Base: código-fonte 1.0.316+316. Objetivo: reproduzir RTSP H.264 em rota isolada sem inicializar IA, para comparação com o LibVLC e diagnóstico seguro do primeiro frame.

### Mudanças

- Bibliotecas Media3 `exoplayer-rtsp` e `ui` 1.8.0, alinhadas ao ExoPlayer do rádio.
- `Media3RtspPlatformView` cria um ExoPlayer por prévia, suporta RTSP TCP forçado ou UDP com fallback, autenticação BASIC/DIGEST nativa da biblioteca e decodificação via codecs do Android.
- Emite estados e **primeiro frame efetivamente renderizado**; envia apenas nome de erro técnico, nunca URL/senha/stacktrace.
- `Media3RtspTestScreen` usa AndroidView e é aberta em Câmeras > menu de uma câmera RTSP > Testar H.264 com Media3. Mostra resolução e diagnóstico de ausência de frame após 20 segundos, sem afirmar falso êxito.
- Pausa em segundo plano, retoma ao voltar, libera player ao fechar e permite nova tentativa.
- Continua disponível o monitoramento LibVLC com IA. MCRP, mapas, gravações e módulos opcionais não sofreram migração nesta versão.

### Escopo e limites

- Esta é uma rota de **teste** e não torna ExoPlayer o padrão do Monitorar nesta versão. Não há integração de frames RGB para IA, validação antes de salvar nem compatibilidade H.265 afirmada.
- ExoPlayer RTSP exige stream H.264 compatível, incluindo SPS/PPS presentes no SDP. Algumas câmeras podem não funcionar mesmo usando URL correta.
- `tool/verify_project.sh` passou integralmente: 323 testes Python na suíte geral (1 ignorado), além dos checadores adicionais. Compilação Android, teste de reprodução RTSP real e medição de CPU/RAM/temperatura dependem de GitHub Actions e aparelhos físicos.
- Nenhuma assinatura/secrets incorporados.
