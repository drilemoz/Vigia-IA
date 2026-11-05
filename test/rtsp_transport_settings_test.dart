import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/camera_endpoint.dart';
import 'package:vigiaia/models/video_source_config.dart';

void main() {
  test('novo cadastro RTSP usa transporte automático e persiste', () {
    const endpoint = CameraEndpoint(
      id: 'camera-1',
      name: 'Câmera IP',
      type: CameraEndpointType.rtsp,
      address: 'rtsp://192.168.1.50:554/onvif1',
    );
    expect(endpoint.rtspTransport, 'auto');
    final restored = CameraEndpoint.fromJson(endpoint.toJson());
    expect(restored.rtspTransport, 'auto');
    expect(restored.copyWith(rtspTransport: 'udp').rtspTransport, 'udp');
  });

  test('cadastros antigos preservam escolha TCP ou UDP', () {
    const endpoint = CameraEndpoint(
      id: 'camera-2',
      name: 'Legado',
      type: CameraEndpointType.rtsp,
    );
    final legacyTcp = Map<String, dynamic>.from(endpoint.toJson())
      ..remove('rtspTransport')
      ..['rtspForceTcp'] = true;
    final legacyUdp = Map<String, dynamic>.from(legacyTcp)
      ..['rtspForceTcp'] = false;
    expect(CameraEndpoint.fromJson(legacyTcp).rtspTransport, 'tcp');
    expect(CameraEndpoint.fromJson(legacyUdp).rtspTransport, 'udp');
  });

  test('fonte de vídeo persiste o transporte e mantém fallback legado', () {
    const source = VideoSourceConfig(
      type: VideoSourceType.rtsp,
      rtspUrl: 'rtsp://192.168.1.50/onvif1',
      rtspTransport: 'udp',
    );
    expect(VideoSourceConfig.fromJson(source.toJson()).rtspTransport, 'udp');
    final legacy = Map<String, dynamic>.from(source.toJson())
      ..remove('rtspTransport')
      ..['rtspForceTcp'] = true;
    expect(VideoSourceConfig.fromJson(legacy).rtspTransport, 'tcp');
  });
}
