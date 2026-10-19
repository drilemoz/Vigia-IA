import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/vehicle_plate_ocr_service.dart';

void main() {
  test('normaliza formatos antigo e Mercosul', () {
    expect(BrazilianPlateText.normalize('abc-1234'), 'ABC1234');
    expect(BrazilianPlateText.normalize('abc1d23'), 'ABC1D23');
    expect(BrazilianPlateText.normalize('ABC-I234'), 'ABC1234');
  });
  test('encontra placas no OCR e rejeita texto de tamanho incorreto', () {
    expect(BrazilianPlateText.bestCandidate('PLACA: ABC1D23\nBRASIL'), 'ABC1D23');
    expect(BrazilianPlateText.bestCandidate('ABC-1234'), 'ABC1234');
    expect(BrazilianPlateText.bestCandidate('sem placa'), isNull);
    expect(BrazilianPlateText.normalize('ABC123'), isNull);
    expect(BrazilianPlateText.normalize('ABC12D4'), isNull);
  });
}
