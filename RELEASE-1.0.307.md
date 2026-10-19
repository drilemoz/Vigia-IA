# Vigia IA 1.0.307+307

## Gravação do transmissor e fotos locais

- O gravador MP4 do Redmi A3 recebe quadros antes da compressão de rede, com timestamps do momento da captura, reduzindo disputa e atraso. Exibe contadores de quadros aceitos e descartados na tela Transmissão.
- A nova opção **Fotos por movimento no transmissor** salva JPEGs no próprio A3 por mudanças de cena, mesmo que o Note 11 não esteja aberto, desde que o serviço do A3 permaneça ativo. Desativada inicialmente.
- Cadência limitada a 1 foto por 30 segundos e 60 por hora. Não é reconhecimento automático de carros, nem substitui a detecção com IA do Note 11. Não faz OCR nem consulta API; o usuário pode abrir os JPEGs pela Galeria Remota.
- Durante REC e temperatura alta, fotos são temporariamente suspensas para aliviar carga. Se o serviço de câmera for encerrado no Android, não fotografa.
- Metadados, tela Sobre, Novidades, README, CHANGELOG e documentação sincronizados.

## Validação pendente

- Testar comportamento real no Redmi A3: FPS do MP4, fluidez, autonomia e aquecimento; `flutter analyze`, `flutter test` e `assemble` no GitHub Actions.
