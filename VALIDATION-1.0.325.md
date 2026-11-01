# Validação — Vigia IA 1.0.325+325

- `python3 -m unittest discover -s tool -p 'test_*.py' -q`: 359 testes, 358 aprovados e 1 ignorado.
- `PATH` sem Kotlin/JDK especial `bash tool/verify_project.sh`: aprovado, com grupo Kotlin/JVM dispensado; 4 skips de testes dependentes do ambiente.
- `tool/test_gemini_maps_325.py`: 4 contratos aprovados; proteção Android Keystore, bootstrap, acionamentos UI, integração verificada, versão.
- `python3 tool/check_version_sync.py` e `tool/check_release_consistency.py`: aprovados.
- Arquivos XML das regras de backup: validáveis por parser XML; sem segredos embutidos no código.
- `test/gemini_map_suggestion_test.dart`: teste Flutter adicionado, mas **não executado** porque não há SDK Flutter neste ambiente.
- **Não executados**: `flutter analyze`, `flutter test`, build Android/Gradle, autenticação real Gemini, Nominatim em dispositivo e testes de interface física. Validar no GitHub Actions e celular antes de publicar.
- A chave do Uai Cortes não é importada automaticamente: cada app tem seu armazenamento privado Android.
