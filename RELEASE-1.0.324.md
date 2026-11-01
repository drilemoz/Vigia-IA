# Vigia IA 1.0.324+324 — Correções de busca e interface dos Mapas

- Planejamento: busca Nominatim inclui limites administrativos de cidades e municípios; campo oferece botão Buscar explícito e lista de seleção antes de habilitar Avançar. Nenhuma busca online automática a cada tecla (limitação de uso do Nominatim público).
- Assistente compacto: Dialog responsivo com rolagem e ações agrupadas, sem espaço vazio excessivo; saída, intervalo das pausas, duração e almoço em grade 2x2.
- Mapa: remove AppBar branca isolada, projeta mapa sob o topo e move HUD abaixo do cabeçalho transparente.
- Prévia: altura limitada com rolagem, distâncias relativas de alternativas exibidas mesmo quando rota 1 está selecionada; sem alegar relevo/pavimento/segurança não medidos.
- Indicadores: diferenciam bússola de velocidade GPS; marcador GPS ao vivo deixa de sugerir posição atual quando a leitura é antiga.
- Tempo: estimativas Bike em minutos com arredondamento para cima, em acordo com o planejador diário; apresentação de pausas harmonizada.
- Módulos de câmera/IA/ESP32 não foram modificados.

Pendências: `flutter analyze`, `flutter test`, build Android em GitHub Actions e inspeção visual no celular.
