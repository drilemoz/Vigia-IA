# Vigia IA 1.0.314+314 — Diagnóstico automático

A coleta começa automaticamente com o processo, sem botão ou configuração. As correções de transmissão/REC de 1.0.313 permanecem.

## Dados registrados

- Modelo, fabricante, Android/API, arquitetura e versão/build da sessão.
- A cada 10 segundos enquanto a interface, monitoramento ou transmissor estiver ativo: CPU do processo (100% = um núcleo), heap Java/nativo, RAM disponível, pouca memória, espaço livre, bateria, temperatura, carregamento, proteção térmica, economia de energia e tela interativa.
- Tipo de conexão, contadores de tráfego do app e validação de internet, permissão de câmera; sem coleta de SSID, MAC ou endereço completo da câmera pela amostragem.
- Estado do monitor/IA, FPS disponível, último quadro, LAN, clientes e erros; tempo dos quadros da interface, quantidade acima de 32 ms e idade dos heartbeats Flutter/Android.
- Transmissão: codec, FPS solicitado, capturados, aceitos/descartados no REC, idade do último quadro/codificação, espectadores e estado térmico. Eventos e investigação de congelamento já existentes são incorporados ao relatório.
- Erros da interface, assíncronos do isolate principal, isolate de IA, inicialização e demais erros encaminhados à central. Java/Kotlin fatal registra classe, stack e snapshot antes de delegar ao Android.
- Motivo, horário, status, importância e memória informados pelo Android 11+ para a saída do processo principal, sem depender de cadastro RTSP. Quando disponível, extrai apenas linhas de métodos do início do trace de ANR (leitura limitada a 32 KiB); não interpreta tombstone binário.

## Ao reabrir

Um erro não tratado registrado ou encerramento anormal identificado abre “Erro detectado no último uso”, antes de novidades/permissões, oferecendo exportação para Downloads. Não precisa iniciar o diagnóstico previamente. Não há upload automático. A versão/estado anterior fica preservada, separada da sessão atual.

“Agora não”, cancelamento ou falha ao salvar mantêm o incidente para nova tentativa na próxima abertura. Confirmação só ocorre depois de salvar com sucesso. Até três incidentes pendentes são mantidos, priorizando os mais recentes; o popup oferece o mais recente a cada abertura. A exportação manual inclui a nova seção automática.

## Limites e privacidade

- 30 amostras (aproximadamente cinco minutos de atividade), 40 eventos nativos, 200 entradas da central e três incidentes. Escritas fora da thread principal, coalescidas para eventos comuns; nenhuma escrita por quadro. O último intervalo pode se perder se o processo for morto abruptamente.
- A ausência de encerramento “limpo” não é usada para inventar um crash. Fechamento pelo usuário, atualização e troca de permissão não geram alerta sozinhos. Falta de memória é descrita como encerramento pelo Android, sem atribuir defeito ao código.
- Android 10 não fornece ApplicationExitInfo. Sinais/razões desconhecidas, desligamento, força de parada, OOM extremo e morte antes da persistência podem não permitir identificar a causa. A coleta não garante capturar toda falha nativa nem contém tombstone completo.
- Heartbeat atrasado e quadros acima de 32 ms são evidências de lentidão, não confirmação automática de ANR. ANR é classificado quando informado pelo Android.
- Logs novos e antigos passam por redação de URIs/credenciais reconhecidas. FormatException não guarda a entrada original; stack e mensagem técnica são preservados. Não se capturam fotos, áudio, vídeo ou localização no novo coletor.

## Validação

Ver `VALIDATION-1.0.314.md`. É uma entrega de código-fonte: Flutter Analyze, Flutter Test, build APK e teste físico no A3 ainda precisam ser confirmados no workflow/aparelho.

## Roteiro físico

1. Instalar build 314, usar em modo normal e Transmissão sem abrir diagnóstico; exportar diagnóstico manual e conferir novas amostras.
2. Em build de teste, provocar erro Flutter não tratado e crash Java controlado; reabrir, conferir versão anterior e exportação em Downloads.
3. Escolher Agora não/reabrir, testar falha de armazenamento e conferir retenção; após exportar com sucesso, reabrir e confirmar que o mesmo incidente não reaparece.
4. Em Android 11+, reproduzir ANR/crash nativo de teste e confirmar a razão do sistema; fechamento comum/remoção dos recentes sem erro não deve anunciar crash.
5. Gravar e transmitir no A3 por dez minutos, inclusive com tela apagada, verificando fluidez e custo do coletor; não foi medido em aparelho neste ambiente.
