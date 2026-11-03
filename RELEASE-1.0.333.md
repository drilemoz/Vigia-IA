# Vigia IA 1.0.333+333 — Maps SDK com chave opcional de build

## Entrega

- Secret opcional `MAPS_API_KEY` no GitHub Actions, consumido pelo Gradle para incluir a chave no manifesto Android.
- Chave digitada pelo usuário continua criptografada no aparelho, mas não é mais falsamente apresentada como ativação do Maps SDK.
- Retirada a injeção não documentada em `ApplicationInfo.metaData`; chave de build é lida do manifesto instalado.
- Central de seis APIs indica separadamente o uso efetivo de cada serviço (Geoapify/ORS ainda pendentes de integração).
- Navegação offline, RTSP, H.264/MJPEG, Gemini, Stadia e Open-Meteo preservados.

## Como ativar o Google Maps no APK

1. Google Cloud: habilitar o Maps SDK for Android e faturamento, criar chave e restringir a `com.vigiaia.app` e SHA-1 da keystore de release.
2. GitHub: definir o Secret `MAPS_API_KEY` com essa chave. Não adicionar chaves ao código ou a commits.
3. Executar a action Android APK e instalar o APK assinado correspondente. A chave anterior salva no aparelho não muda o manifesto.
4. Validar em aparelho: abrir Google Maps e verificar mapa/logcat; ausência de erro de autenticação e tiles reais.

Sem Secret, o app continua com OpenStreetMap/recursos offline. Chave Maps SDK incorporada ao APK não é segredo de fato: segurança depende das restrições do Google Cloud. Compilação/testes no Android ainda pendentes.

## Validação local

`tool/verify_project.sh` aprovado, incluindo 392 testes Python (1 ignorado). Verificadores de versão e contratos Maps SDK aprovados. O Flutter SDK não está instalado neste ambiente; análise Dart e build Android seguem pendentes.
