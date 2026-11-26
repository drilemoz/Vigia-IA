# Validação 1.0.383 — build 327

O log do build 327, na versão 1.0.382, mostra que a verificação preventiva concluiu e que `flutter analyze --fatal-infos --fatal-warnings` retornou `No issues found!`. A preparação do YOLO26s falhou ao compilar `pydantic-core`: PyO3 0.24.1 suporta até Python 3.13, enquanto o runner usava 3.14.

A correção fixa Python 3.12 no workflow antes da verificação preventiva e da exportação, com guarda explícita antes do pip. Mantém os pins de exportação já existentes e exige o modelo real validado no APK. Não usa bypass ABI, não desativa lints nem remove o modelo offline.

Validação local: oito testes focados aprovados (incluindo três novos testes); checagem de versão e base aprovadas; sintaxe Bash e estrutura YAML conferidas. A exportação real do modelo, o Flutter Analyze da nova versão, testes Flutter e compilação Android precisam ser confirmados no CI. A suíte geral local não foi concluída no limite de execução.
