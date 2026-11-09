# Validação 1.0.376+376

- Bases: logs Android APK 320 e 321 fornecidos pelo usuário e ZIP-fonte 1.0.375+375 validado.
- Ambos os workflows completaram a verificação preventiva e falharam em `flutter analyze --fatal-infos --fatal-warnings`: `unnecessary_non_null_assertion` em `lib/services/bike_trip_planner.dart`, linhas 141/147.
- Fix: único `!` redundante removido do cálculo do alvo por quilômetros; nenhuma outra fórmula alterada.
- Regressão: `tool/test_build321_lint_376.py` incluído no verificador preventivo.
- Resultados locais: `python3 -m unittest discover -s tool -p test_*.py -q` executou 577 testes, 576 aprovados, 1 pulado (SDK Dart), sem falhas; `bash tool/verify_project.sh` encerrou com código 0. Verificadores de versão, Novidades, baseline e release passaram; ZIP validado por CRC e comparação de inventário. O teste estático preventivo passou.
- Limites: SDK Flutter não disponível no ambiente local; compilar e executar Dart/Flutter no GitHub Actions.
