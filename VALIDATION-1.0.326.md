# Validação 1.0.326+326

- Testes preventivos da ordem permissões → Serviços e APIs → modo e retomada após interrupções.
- Paridade entre `MainActivity.kt` e `tool/android/MainActivity.kt` para garantir consistência no CI.
- Configuração Gemini/Google/Stadia reutiliza as telas existentes, sem expor segredos no onboarding.
- `flutter analyze`, `flutter test` e `assemble` ainda dependem do GitHub Actions e testes no Android.

## Execuções locais

- `python -m unittest discover -s tool -p 'test_*.py' -q`: 363 testes executados; 362 aprovados, 1 ignorado.
- `tool/verify_project.sh` com compilador Kotlin fora do PATH: aprovado, incluindo 363 testes e 4 ignorados no subprocesso isolado.
- `python tool/check_version_sync.py` e `python tool/check_release_consistency.py`: aprovados.
- Android físico, `flutter analyze`, `flutter test`, compilação APK e teste das três APIs: **não executados localmente**.
