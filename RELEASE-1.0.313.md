# Vigia IA 1.0.313+313 — transmissão e gravação no A3

## Alterações

- O callback Camera encaminha o quadro NV21 ao gravador e à transmissão por caminhos independentes. O encoder de rede ocupado não bloqueia o encaminhamento ao REC. Cada caminho aceita no máximo um quadro em processamento, evitando filas crescentes.
- O gravador usa o quadro original, sem rotação de pixels. A orientação fica fixa no metadado MP4 via MediaMuxer.setOrientationHint. A rotação física continua somente na transmissão, preservando o receptor atual.
- Conversão NV21 para I420/NV12 diretamente no ByteBuffer do encoder. Removida a alocação do vetor intermediário em ambos os encoders.
- Gravação seleciona encoder H.264 de hardware com tamanho/FPS e formato de entrada compatíveis. Se indisponível, apresenta erro para tentar 480p/10 FPS; não força processamento por software silenciosamente.
- O FPS da gravação é fixado a partir da seleção ao iniciar REC. Alterar o FPS de rede durante REC não muda a cadência nominal dessa gravação. Os limites térmicos continuam valendo para ambas as saídas.
- Cadência por prazo monotônico, com tolerância de 2 ms ao jitter; callbacks ligeiramente antecipados não reduzem a taxa pela metade. Pausas não geram rajadas de compensação.
- Removido o teto adicional fixo de 5 FPS da rede durante REC com receptor. Sem receptor, seguem apenas amostras de status a cada 2,5 s, sem limitar o gravador.
- H.264 usa histórico limitado a 24 pacotes/4 MiB e cursor por receptor. Descartes, reinício do encoder ou atraso superior a 1 s obrigam retomada em quadro-chave, solicitado com limite de frequência. SPS/PPS acompanham os quadros-chave.
- A interface expõe 5, 10, 15, 24 e 30 FPS já aceitos pelo protocolo. 10 FPS e 480p continuam como valores padrão; FPS escolhido é uma meta, não garantia.
- Proteções térmicas mantidas: WARM até 5 FPS, HOT até 2 FPS; parada de emergência preservada. Eco sem REC continua até 5 FPS.
- Fontes de recuperação em tool/android/native_transmitter sincronizadas. Cadastro/reprodução RTSP não alterados nesta entrega.

## Verificação no aparelho

1. Em 480p, Normal e 10 FPS, gravar 60 s sem receptor. Conferir o MP4 e os contadores REC.
2. Repetir com receptor conectado; comparar os FPS publicados, quadros REC, descartes, CPU e estado térmico.
3. Conferir orientação vertical e horizontal dos arquivos MP4, inclusive reprodução e cópia pela Galeria Remota.
4. Experimentar 15 FPS; aumentar só se a taxa medida acompanhar. Eco e aquecimento podem reduzir o resultado.
5. Se usar o caminho H.264 experimental, verificar conexão inicial, múltiplos clientes, atraso de rede e retomada por quadro-chave.
6. Iniciar/parar REC rapidamente e encerrar a transmissão durante REC: verificar a finalização do arquivo.

## Limites da validação

Consultar VALIDATION.md. Não há medição de desempenho no Redmi A3 físico nem APK completo compilado nesta entrega.
