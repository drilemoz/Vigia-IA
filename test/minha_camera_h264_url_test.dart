import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/minha_camera_live_url.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';
  test('deriva H264 apenas de QR local válido', () {
    const live = 'http://192.168.100.10:8765/live/$token';
    final h264 = MinhaCameraLiveUrl.h264FromLive(live);
    expect(h264.toString(), 'http://192.168.100.10:8765/h264/$token');
    expect(MinhaCameraLiveUrl.isValidH264(h264.toString()), isTrue);
    expect(MinhaCameraLiveUrl.isValid(live), isTrue);
  });

  test('rejeita URL pública, credenciais, redirecionamento e rotas livres', () {
    for (final bad in <String>[
      'http://8.8.8.8:8765/live/$token',
      'http://usuario:senha@192.168.1.2:8765/live/$token',
      'http://192.168.1.2:8765/live/$token?token=abc',
      'http://192.168.1.2:8765/foo/$token',
    ]) {
      expect(MinhaCameraLiveUrl.h264FromLive(bad), isNull);
    }
    expect(MinhaCameraLiveUrl.isValidH264('http://8.8.8.8:8765/h264/$token'), isFalse);
    expect(MinhaCameraLiveUrl.isValidH264('http://192.168.1.2:8765/h264/bad'), isFalse);
  });
}
