import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_navigation_instruction_ptbr.dart';

void main() {
  group('Instruções de navegação pt-BR', () {
    test('direções simples, rua preservada', () {
      expect(MapNavigationInstructionPtBr.localize('Turn right onto Rua Central'),
          'Vire à direita na Rua Central');
      expect(MapNavigationInstructionPtBr.localize('Turn left'),
          'Vire à esquerda');
      expect(MapNavigationInstructionPtBr.localize('Head southeast'),
          'Siga na direção sudeste');
      expect(MapNavigationInstructionPtBr.localize('Head southeast.'),
          'Siga na direção sudeste.');
      expect(MapNavigationInstructionPtBr.localize('Keep right'),
          'Mantenha-se à direita');
    });

    test('curvas específicas, instruções já traduzidas e texto vazio', () {
      expect(MapNavigationInstructionPtBr.localize('Make a U-turn'),
          'Faça o retorno');
      expect(MapNavigationInstructionPtBr.localize('Continue straight'),
          'Siga em frente');
      expect(MapNavigationInstructionPtBr.localize('Vire à direita'),
          'Vire à direita');
      expect(MapNavigationInstructionPtBr.localize(' '),
          'Siga pela rota destacada');
    });
  });
}
