import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/api_credentials_backup_service.dart';

void main() {
  test('arquivo .env válido é importado sem senha', () {
    final data = ApiCredentialsBackupService.parsePlaintextEnv(
      '# comentário\nGEMINI_API_KEY=AIzaEXEMPLO\n'
      'export GEOAPIFY_API_KEY=testeGeo\nGEMINI_MODEL=gemini-3.5-flash-lite\n',
    );
    expect(data.providers, containsAll(<String>['gemini', 'geoapify']));
    expect(data.includesGeminiModel, isTrue);
  });

  test('arquivo com chave duplicada é rejeitado', () {
    expect(
      () => ApiCredentialsBackupService.parsePlaintextEnv(
        'STADIA_API_KEY=abc\nSTADIA_API_KEY=def\n',
      ),
      throwsFormatException,
    );
  });

  test('chave desconhecida ou com quebra de linha é rejeitada', () {
    expect(
      () => ApiCredentialsBackupService.parsePlaintextEnv('CUSTOM_KEY=abc'),
      throwsFormatException,
    );
    expect(
      () => ApiCredentialsBackupService.parsePlaintextEnv(
        'GEOAPIFY_API_KEY=abc\nvalorSemIgual\n',
      ),
      throwsFormatException,
    );
  });

  test('não aceita somente modelo sem credenciais', () {
    expect(
      () => ApiCredentialsBackupService.parsePlaintextEnv(
        'GEMINI_MODEL=gemini-3.5-flash-lite\n',
      ),
      throwsFormatException,
    );
  });
}
