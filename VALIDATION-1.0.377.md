# Validação 1.0.377+377

- Base: ZIP 1.0.376 anexado pelo usuário, versão confirmada no pubspec. Drive/repositório não verificados.
- 22 testes estáticos focados (GPS, APIs, integração, versão e regressões) aprovados.
- `tool/check_release_consistency.py` aprovado.
- `tool/verify_project.sh` iniciado; execução integral interrompida pelo limite do ambiente, sem resultado conclusivo.
- Flutter/Dart SDK indisponíveis: análise, testes Dart e APK precisam do CI. Testes de parser adicionados, não executados.
- Sem teste de GPS em aparelho nem chamadas autenticadas às APIs. Geoapify testa geocodificação; roteamento tem operação/cota distinta.
- Valhalla não fornece dados de superfície neste fluxo. Modo chuva exclui alternativas com terra conhecida quando o provedor informa a superfície; desconhecido exige conferência. Dados OSM podem estar desatualizados.
- Nenhuma dependência ou assinatura modificada; workflow Android preservado.
