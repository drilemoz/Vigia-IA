import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/gemini_map_service.dart';

void main() {
  group('GeminiMapSuggestion.parse', () {
    test('parseia consulta curta e justificativa', () {
      final item = GeminiMapSuggestion.parse(
        '{"search_query":"camping, Lagoa da Prata, MG",'
        '"explanation":"Vou procurar lugares cadastrados."}',
      );
      expect(item.searchQuery, 'camping, Lagoa da Prata, MG');
      expect(item.explanation, contains('cadastrados'));
    });

    test('não aceita consultas vazias nem longas', () {
      expect(() => GeminiMapSuggestion.parse('{"search_query":""}'),
          throwsFormatException);
      final longQuery = List<String>.filled(181, 'a').join();
      expect(
        () => GeminiMapSuggestion.parse(
          '{"search_query":"$longQuery"}'),
        throwsFormatException,
      );
    });

    test('interpreta JSON com delimitador markdown sem inventar local', () {
      final item = GeminiMapSuggestion.parse(
        '```json\n{"search_query":"Piumhi, Minas Gerais",'
        '"explanation":"Consulta a verificar."}\n```',
      );
      expect(item.searchQuery, 'Piumhi, Minas Gerais');
    });
  });
}
