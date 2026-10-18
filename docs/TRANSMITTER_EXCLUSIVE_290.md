# Vigia IA 1.0.290 · Transmissor Exclusivo

## Escopo implementado

- `AppLaunchModeService` restaura o último modo salvo em `launch_mode.json` e sincroniza o guard Dart/nativo ao iniciar, antes de carregar módulos opcionais. **Não reinicia a câmera automaticamente após o processo ser encerrado**, por segurança e restrições do Android.
- O modo Transmissão usa `PopScope` sem barra de navegação de outros destinos. O único caminho de saída solicita confirmação, desliga a transmissão e aguarda a liberação do serviço, inclusive finalização de MP4, antes de trocar o papel do aparelho.
- O guard nativo persiste o estado em `SharedPreferences` e impede iniciar o serviço de monitoramento e rádio. O receptor de recuperação do monitoramento ignora eventos enquanto Transmissão estiver selecionado. Serviços Flutter já inicializados interrompem os timers de ESP32, segurança Bike e uso de dados ao mudar de modo.
- A contagem de espectadores do servidor MCRP inclui apenas conexões de vídeo, não HTTP de status. Sem espectador nem REC, os callbacks de câmera mantêm uma imagem JPEG ocasional (intervalo mínimo 2,5s), reduzindo cópias e compressão, mas conservando a câmera aberta para reconexão rápida. A gravação local conserva sua própria cadência.
- Em novas instalações a opção Eco inicia ativada; o ajuste Eco anteriormente salvo é respeitado. O FPS solicitado ao driver da câmera também tenta refletir Eco e proteção térmica, dentro das faixas realmente suportadas pelo dispositivo.
- O serviço consulta `PowerManager.currentThermalStatus` em Android API 29+ a cada 5 segundos, em conjunto com a temperatura de bateria. Reduz qualidade e cadência em `WARM/HOT`, publica `X-Thermal-Status` no MCRP e interrompe a captura em emergência térmica, utilizando a finalização segura da gravação existente.

## Limites e segurança

- Não bloqueia serviços do Android nem aplicativos de terceiros. Wake locks de CPU e Wi-Fi de alto desempenho continuam necessários para validar transmissão com tela apagada antes de serem removidos/rebaixados.
- No Wi-Fi sem espectadores a câmera não é encerrada automaticamente: a economia esperada vem principalmente de menos JPEGs; o sensor e o canal MCRP ainda consomem energia.
- Não há medição física comprovando menor descarga ou menor temperatura em relação à versão 1.0.289 ou ao aplicativo Minha Câmera.
- Retomada remota de captura via MCRP exige serviço ativo e token previamente pareado; câmera finalizada completamente não é iniciada em segundo plano por comunicação avulsa.

## Protocolo de validação no Redmi A3

1. Compilar APK ARM compatível no GitHub Actions; aprovar `flutter analyze` e testes Flutter.
2. Testar modo Transmissão -> tela apagada -> 1 receptor, com 480p, Eco e 5 FPS; verificar stream MCRP/REC durante 30 minutos.
3. Repetir 30 minutos sem receptor, observando intervalo de quadros, callback da câmera, bateria, temperatura e perda de conexão.
4. Testar MP4 ativo sem receptor: a redução de quadros ociosos **não** pode interromper gravação nem corromper o arquivo.
5. Testar pausa/retomada MCRP com tela apagada, troca de Wi-Fi/hotspot, início de gravação e finalização ordenada.
6. Verificar que Ao vivo, Mapas, ESP32, IA, rádio, dados e monitoramento nativo permanecem inativos enquanto o papel Transmissão estiver selecionado; ao sair, outros papéis voltam a funcionar.
7. Reiniciar o processo e confirmar que abre no último papel escolhido; não deve ativar a câmera sem ação explícita.
8. Em bancada segura, observar política térmica sob condições controladas. Não aquecer artificialmente a bateria nem usar sol direto para forçar a proteção. Temperatura da bateria e status térmico Android não são equivalentes.

## Testes locais de código

- `python3 -m unittest discover -s tool -p 'test_*.py' -q`
- `bash tool/verify_project.sh`
- Kotlin isolado de `PhoneCameraServer.kt` e `PhoneEcoPolicy.kt` com stubs mínimos Android.
- `flutter analyze`, `flutter test` e o build Android completo são pendentes quando Flutter SDK está indisponível.
