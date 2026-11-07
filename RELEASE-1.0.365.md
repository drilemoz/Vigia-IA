# Vigia IA 1.0.365+365 — GPS e busca de pontos

- O topo de mapas diferencia ausência de permissão/desativação de GPS de leituras com timestamp antigo. A coordenada antiga continua sendo histórica, nunca tratada como atual.
- Com mapa visível no Android, o GPS de consulta passiva pede atualizações aproximadas a cada 15 segundos mesmo parado, com precisão moderada e sem manter assinatura após fechar o mapa. Pode elevar o consumo durante a tela aberta; medir no aparelho.
- POIs: tentativas menores por servidor, total maior para permitir fallback entre instâncias Overpass e mensagens que separam falha da rede de falha de GPS.
- Consulta manual pelo centro visível do mapa, sem GPS e sem excluir ou modificar pacotes locais de pontos.
- Registros de pontos offline, mapas, rotas e câmeras mantidos.
- Testes Python e teste Dart do diagnóstico adicionados. Flutter Analyze, testes Dart e APK ainda dependem de CI.
