/// Localiza instruções de roteadores para português do Brasil sem rede.
/// O provedor deve ser consultado em português; este adaptador cobre respostas
/// antigas/em cache ou servidores que retornem instruções em inglês.
/// Nomes de ruas e destinos são preservados.
class MapNavigationInstructionPtBr {
  const MapNavigationInstructionPtBr._();

  static const Map<String, String> _directions = <String, String>{
    'north': 'norte',
    'northeast': 'nordeste',
    'east': 'leste',
    'southeast': 'sudeste',
    'south': 'sul',
    'southwest': 'sudoeste',
    'west': 'oeste',
    'northwest': 'noroeste',
  };

  static String localize(String text) {
    final value = text.trim();
    if (value.isEmpty) return 'Siga pela rota destacada';

    final heading = RegExp(
      r'^head\s+(northwest|northeast|southwest|southeast|north|south|east|west)\b',
      caseSensitive: false,
    ).firstMatch(value);
    if (heading != null) {
      final direction = _directions[heading.group(1)!.toLowerCase()]!;
      return _finish('Siga na direção $direction', value.substring(heading.end));
    }

    // Priorizar curvas específicas antes de "Turn right/left".
    const patterns = <(String, String)>[
      (r'^make\s+a\s+u[ -]?turn\b', 'Faça o retorno'),
      (r'^turn\s+sharply\s+right\b', 'Vire acentuadamente à direita'),
      (r'^turn\s+sharply\s+left\b', 'Vire acentuadamente à esquerda'),
      (r'^turn\s+slightly\s+right\b', 'Vire levemente à direita'),
      (r'^turn\s+slightly\s+left\b', 'Vire levemente à esquerda'),
      (r'^turn\s+right\b', 'Vire à direita'),
      (r'^turn\s+left\b', 'Vire à esquerda'),
      (r'^keep\s+right\b', 'Mantenha-se à direita'),
      (r'^keep\s+left\b', 'Mantenha-se à esquerda'),
      (r'^bear\s+right\b', 'Siga levemente à direita'),
      (r'^bear\s+left\b', 'Siga levemente à esquerda'),
      (r'^continue\s+straight\b', 'Siga em frente'),
      (r'^go\s+straight\b', 'Siga em frente'),
      (r'^continue\b', 'Continue'),
      (r'^merge\b', 'Entre na via'),
      (r'^enter\s+the\s+roundabout\b', 'Entre na rotatória'),
      (r'^at\s+the\s+roundabout\b', 'Na rotatória'),
      (r'^exit\s+the\s+roundabout\b', 'Saia da rotatória'),
      (r'^you\s+have\s+arrived\b', 'Você chegou ao destino'),
      (r'^arrive\s+at\s+your\s+destination\b', 'Você chegou ao destino'),
      (r'^your\s+destination\s+is\b', 'Seu destino está'),
    ];
    for (final pattern in patterns) {
      final match = RegExp(pattern.$1, caseSensitive: false).firstMatch(value);
      if (match != null) {
        return _finish(pattern.$2, value.substring(match.end));
      }
    }
    // O texto já em português e os nomes próprios não devem ser alterados.
    return value;
  }

  static String _finish(String translated, String suffix) {
    var rest = suffix.trimLeft();
    rest = rest.replaceFirst(RegExp(r'^onto\s+', caseSensitive: false), 'na ');
    rest = rest.replaceFirst(RegExp(r'^on\s+to\s+', caseSensitive: false), 'na ');
    rest = rest.replaceFirst(RegExp(r'^on\s+', caseSensitive: false), 'na ');
    rest = rest.replaceFirst(RegExp(r'^at\s+the\s+intersection\b', caseSensitive: false), 'no cruzamento');
    rest = rest.replaceFirst(RegExp(r'^toward\s+', caseSensitive: false), 'em direção a ');
    if (rest.isEmpty) return translated;
    if (RegExp(r'^[.,;:!?]').hasMatch(rest)) return '$translated$rest';
    return '$translated $rest';
  }
}
