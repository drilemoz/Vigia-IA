# Validação — Vigia IA 1.0.314+314

- `tool/verify_project.sh`: código de saída 0. 525 execuções de testes Python reportadas pelo script; alguns testes são invocados individualmente e depois na descoberta geral, portanto não são 525 testes únicos. Nenhum skip registrado nesta execução.
- Regras Kotlin de classificação de saída (falha, ANR, pouca memória versus saída normal/usuário/sinal desconhecido), limites, remoção de credenciais e extração segura de métodos de ANR executadas em JVM.
- Sanitizador Dart executado com SDK 3.13.6: entrada legada de FormatException removida, stack preservada, campos/URIs/JSON com credenciais fictícias removidos.
- Compilação isolada do módulo nativo `com.minhacamera` e dos novos `AppDiagnostics`, `DiagnosticPolicy`, `VigiaApplication`: Kotlin 2.1.20, Java 17, API Android 34 e AndroidX Core 1.13.1, sem erros. Apenas MainActivity, R.mipmap.ic_launcher e o indicador MonitoringForegroundService.isRunning foram representados por stubs nessa compilação. Não é compilação Gradle do aplicativo completo.
- Testes de transmissão 313 (cadência, buffers YUV, fila AVC e retomada) continuam aprovados; fontes Android/template espelhadas e XMLs verificados.
- Parser/formatador Dart processou os arquivos alterados. Isso não substitui análise de tipos com Flutter.
- Quatro testes Flutter de widget adicionados para ausência de incidente, adiar, falha ao salvar e exportação antes da confirmação. Não executados aqui: Flutter SDK ausente.
- **Pendentes:** `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, APK/Gradle/R8 e roteiro físico no A3. Não foi medida a sobrecarga real da coleta, nem reproduzido crash/ANR no aparelho.
- Projeto fonte: modelos TFLite ausentes são obtidos pelo script já existente antes do build. Não há APK neste ZIP.

Logs desta execução: `validation/1.0.314/verify-project.log`, `native-compile.log` e `diagnostic-rules.log`.
