import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/camera_endpoint.dart';
import 'package:vigiaia/models/video_source_config.dart';
import 'package:vigiaia/services/map_camera_source_policy.dart';

void main() {
  test('conversão RTSP preserva transporte e decodificação', () {
    const endpoint = CameraEndpoint(
      id: 'cam-1', name: 'Garagem',
      type: CameraEndpointType.rtsp,
      address: 'rtsp://192.168.1.10/stream',
      rtspForceTcp: false, rtspSoftwareDecoding: true,
    );
    final source = MapCameraSourcePolicy.fromEndpoint(endpoint);
    expect(source.type, VideoSourceType.rtsp);
    expect(source.cameraId, 'cam-1');
    expect(source.rtspForceTcp, isFalse);
    expect(source.rtspSoftwareDecoding, isTrue);
    expect(source.rtspUrl, endpoint.address);
  });

  test('ESP32 e celular preservam endereços e chaves', () {
    for (final type in <CameraEndpointType>[
      CameraEndpointType.remotePhone, CameraEndpointType.esp32,
    ]) {
      final source = MapCameraSourcePolicy.fromEndpoint(CameraEndpoint(
        id: 'id-${type.name}', name: 'Fonte', type: type,
        address: 'http://192.168.1.20', accessKey: 'segredo',
      ));
      expect(source.remoteBaseUrl, 'http://192.168.1.20');
      expect(source.remoteAccessKey, 'segredo');
    }
  });

  test('não usa fonte local frontal como duplicação da traseira', () {
    const front = VideoSourceConfig(
      type: VideoSourceType.localCamera, cameraId: frontCameraTestId,
    );
    const back = VideoSourceConfig(
      type: VideoSourceType.localCamera, cameraId: 'back',
    );
    expect(MapCameraSourcePolicy.representsSameSource(front, back), isFalse);
    expect(MapCameraSourcePolicy.representsSameSource(front, front), isTrue);
    expect(MapCameraSourcePolicy.representsSameSource(back, back), isTrue);
  });

  test('câmeras remotas usam ID ou endereço sem misturar protocolos', () {
    const a = VideoSourceConfig(type: VideoSourceType.rtsp,
      rtspUrl: 'rtsp://192.168.1.10/a', cameraId: 'a');
    const sameId = VideoSourceConfig(type: VideoSourceType.rtsp,
      rtspUrl: 'rtsp://192.168.1.10/b', cameraId: 'a');
    const other = VideoSourceConfig(type: VideoSourceType.rtsp,
      rtspUrl: 'rtsp://192.168.1.10/b', cameraId: 'b');
    const noId = VideoSourceConfig(type: VideoSourceType.rtsp,
      rtspUrl: 'rtsp://192.168.1.10/a');
    const esp = VideoSourceConfig(type: VideoSourceType.esp32,
      remoteBaseUrl: 'rtsp://192.168.1.10/a');
    expect(MapCameraSourcePolicy.representsSameSource(a, sameId), isTrue);
    expect(MapCameraSourcePolicy.representsSameSource(a, other), isFalse);
    expect(MapCameraSourcePolicy.representsSameSource(a, noId), isTrue);
    expect(MapCameraSourcePolicy.representsSameSource(a, esp), isFalse);
    expect(MapCameraSourcePolicy.representsSameSource(null, a), isFalse);
  });
}
