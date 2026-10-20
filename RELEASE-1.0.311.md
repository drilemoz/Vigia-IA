# Vigia IA 1.0.311+311

## Cronômetros da transmissão e gravação no Redmi A3

- Corrigida a atualização visível do contador, que avançava em saltos de 3 segundos por causa da consulta de status a cada 3 segundos.
- Os valores do serviço Android continuam autoritativos. A tela usa `Stopwatch` e atualização visual a cada segundo, com sincronização e proteção contra oscilações.
- As consultas MCRP permanecem a cada 3 segundos; não aumenta processamento da câmera nem muda o vídeo gravado.
- Gravação, Galeria Remota, OCR local de placas e fotos automáticas de movimento preservados.
- Validação em Android físico e CI Flutter ainda pendentes.
