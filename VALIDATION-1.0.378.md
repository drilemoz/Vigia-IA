# Validação 1.0.378

- Base local 1.0.377+377; pubspec do GitHub main confirmado na mesma versão; Drive lista a 1.0.376.
- 38 testes estáticos focados aprovados (integrações, GPS/pavimento, API central, versão, planejamento e atualizador).
- `tool/verify_project.sh` executado com limite de 35 s: excedeu tempo (124), sem falha nos testes concluídos até o limite. A verificação completa permanece pendente.
- Flutter e Dart não disponíveis; analyze, flutter test, compilação do APK e consultas autenticadas não executados.
- Workflow existente preservado; não foi feito upgrade global de dependências.
- Apoios por amostragem: cobertura não exaustiva, até quatro consultas Geoapify por corredor e cache temporário de 15 minutos; o acesso físico, horários, potabilidade e segurança dos pontos não são garantidos.
- Provedores: ORS bicicleta/carro/caminhada, Geoapify também moto, Valhalla fallback. Comparação complementar quando ORS não oferece alternativas suficientes; não é comparação universal de todos os provedores. Modo chuva mantém avisos para superfície desconhecida.
