# Vigia IA 1.0.336+336 — Validação do APK 281

- Fonte: 1.0.335+335; logs do workflow APK 281 mostraram 406 testes Python preventivos OK e oito diagnósticos do `flutter analyze` na etapa 11.
- Correções restritas ao null-safety e às regras lint; novos testes de regressão `tool/test_build281_flutter_analyze_336.py`.
- Validação local: `bash tool/verify_project.sh` concluído com exit 0; suíte de 413 testes Python (412 aprovados, 1 ignorado).
- Novos testes `tool/test_build281_flutter_analyze_336.py`: 7/7 aprovados. `tool/check_version_sync.py`, `tool/check_release_consistency.py` e integridade de fontes verificados.
- Análise Flutter real e compilação Android: pendentes no CI (SDK Flutter indisponível no ambiente de correção).
