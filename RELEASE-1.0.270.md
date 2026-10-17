# Vigia IA 1.0.270+270

Correção da falha de validação no workflow Android APK 223.

- Removidas três comparações numéricas obsoletas de build em `tool/verify_project.sh` (`versionCode`, `AppMetadata.build` e `app_identity.json.build`), incluindo o erro enganoso que mencionava 254.
- A checagem agora usa `tool/check_version_sync.py` para confrontar dinamicamente `pubspec.yaml`, `github-manager.json` (incluindo android.versionCode), `app_identity.json`, metadados Dart e testes. **Não desativa a validação.**
- Adicionada regressão que simula divergência de `versionCode` e verifica que o validador rejeita o projeto.
- Preservadas as melhorias de mapa compacto, áudio e histórico de eventos da 1.0.269.
- Restaurado o rótulo **Gargalo provável** no painel Status da sessão, mantendo o layout compacto.
- Atalhos de mapa e áudio movidos para a extensão de interface (`monitor_screen_portrait.dart`) para respeitar o limite de 1400 linhas do monitor.
- Atualizados os contratos que ainda esperavam que o botão Mapa abrisse Pontos próximos; a busca de pontos permanece disponível no **Painel**.
- Esta é uma correção de CI, não um ganho de FPS ou correção comprovada dos problemas no aparelho.

Flutter Analyze, testes Flutter e APK ainda precisam de execução na CI.
