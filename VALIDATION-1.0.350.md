# Validação — Vigia IA 1.0.350+350

- Fonte baseada na 1.0.349+349.
- Log do APK 294 (04/11/2026): `flutter analyze` foi interrompido por uma instrução `if` sem bloco em `map_monitoring_screen.dart:538`, regra `curly_braces_in_flow_control_structures`.
- Correção mantém a mesma condição de retorno da telemetria, altera apenas a sintaxe e adiciona teste estrutural preventivo.
- `bash tool/verify_project.sh`: **aprovado**, conclusão explícita no log. Suíte Python consolidada: **471 testes executados, 1 ignorado, 0 falhas**.
- Testes específicos do lint: **2 aprovados**, adicionados à verificação preventiva; verificadores de versão, Novidades e contratos históricos aprovados.
- Integridade do ZIP: verificada após empacotamento.
- Flutter SDK indisponível localmente: `flutter analyze`, `flutter test`, APK e teste real em aparelho dependem de GitHub Actions.
