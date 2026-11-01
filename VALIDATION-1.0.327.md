# Validação Vigia IA 1.0.327+327

## Resultados obtidos no código-fonte

- `bash tool/verify_project.sh`: **aprovado** até a verificação final `check_home_default_250.py`, sem falhas no log da execução integral.
- A suíte Python do verificador executou **368 testes, 367 aprovados e 1 ignorado**.
- `python tool/check_version_sync.py`: **aprovado**.
- `python tool/check_release_consistency.py`: **aprovado**.
- `tool/test_api_services_setup_327.py`: **5 testes aprovados** na execução isolada; verificam os seis provedores, ajuda, armazenamento/backup, endpoints de teste e controles Google Maps.
- O arquivo nativo `MainActivity.kt` permanece idêntico à cópia de `tool/android/MainActivity.kt`.
- Regras de backup excluem o armazenamento privado de Gemini, Google Maps e novas chaves parceiras.

## Ainda pendente em ambiente com Android/Flutter

- **Não executados** `flutter analyze`, `flutter test`, Gradle `assemble`, Android lint e testes instrumentados: o Flutter SDK não está instalado neste ambiente.
- Testes de instalação, layout, criptografia/recuperação de chaves e de rede com contas reais no aparelho.
- Geoapify e OpenRouteService ainda **não** estão ativos nas buscas e rotas; somente o gerenciamento e os testes explícitos de conexão foram implementados.
- Google Maps apenas verifica se a chave está cadastrada. Autorização real precisa ser validada usando o Maps SDK Android e a assinatura SHA-1 do APK.

## Evidências para continuar

- Próxima etapa: compilar 1.0.327 no GitHub Actions e testar a interface em aparelho antes de começar a integração da busca (1.0.328).
