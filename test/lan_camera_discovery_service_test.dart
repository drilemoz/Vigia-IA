import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/lan_camera_discovery_service.dart';

void main() {
  test('reconhece Vigia IA e nao recebe chave de pareamento', () {
    final result = LanCameraDiscoveryService.parseResponse(
      'VIGIAIA_HERE_V1|23129RN51X', '192.168.1.55',
    );
    expect(result?.kind, LanCameraKind.vigiaIa);
    expect(result?.host, '192.168.1.55');
    expect(result?.name, contains('23129RN51X'));
    expect(result?.name, isNot(contains('/live/')));
  });

  test('recusa respostas de enderecos publicos', () {
    expect(LanCameraDiscoveryService.parseResponse(
      'VIGIAIA_HERE_V1|Phone', '8.8.8.8',
    ), isNull);
  });

  test('interpreta XAddrs ONVIF como configuracao, nunca stream RTSP', () {
    final response = '''<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope">
<e:Body><d:ProbeMatches xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
<d:ProbeMatch><d:XAddrs>http://192.168.1.90/onvif/device_service</d:XAddrs></d:ProbeMatch>
</d:ProbeMatches></e:Body></e:Envelope>''';
    final result = LanCameraDiscoveryService.parseResponse(response, '192.168.1.90');
    expect(result?.kind, LanCameraKind.onvif);
    expect(result?.onvifServiceUrl, contains('/onvif/device_service'));
  });

  test('recusa host remoto injetado no XAddrs', () {
    final response = '<d:ProbeMatches><d:XAddrs>http://8.8.8.8/onvif</d:XAddrs></d:ProbeMatches>';
    expect(LanCameraDiscoveryService.parseResponse(response, '192.168.1.90'), isNull);
  });
}
