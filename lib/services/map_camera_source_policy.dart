import '../models/camera_endpoint.dart';
import '../models/video_source_config.dart';

/// Conversão e identidade das câmeras mostradas nos PiPs do mapa.
/// Não inicia streaming, GPS nem análise por IA.
class MapCameraSourcePolicy {
  const MapCameraSourcePolicy._();

  static VideoSourceConfig fromEndpoint(CameraEndpoint camera) =>
      switch (camera.type) {
        CameraEndpointType.local => VideoSourceConfig(
            type: VideoSourceType.localCamera,
            displayName: camera.name,
            cameraId: camera.id,
          ),
        CameraEndpointType.rtsp => VideoSourceConfig(
            type: VideoSourceType.rtsp,
            rtspUrl: camera.address,
            rtspSoftwareDecoding: camera.rtspSoftwareDecoding,
            rtspForceTcp: camera.rtspForceTcp,
            displayName: camera.name,
            cameraId: camera.id,
          ),
        CameraEndpointType.remotePhone => VideoSourceConfig(
            type: VideoSourceType.remotePhone,
            remoteBaseUrl: camera.address,
            remoteAccessKey: camera.accessKey,
            displayName: camera.name,
            cameraId: camera.id,
          ),
        CameraEndpointType.esp32 => VideoSourceConfig(
            type: VideoSourceType.esp32,
            remoteBaseUrl: camera.address,
            remoteAccessKey: camera.accessKey,
            displayName: camera.name,
            cameraId: camera.id,
          ),
      };

  /// Evita a duplicação da mesma origem nos dois PiPs.
  static bool representsSameSource(
    VideoSourceConfig? first,
    VideoSourceConfig? second,
  ) {
    if (first == null || second == null || first.type != second.type) {
      return false;
    }
    if (first.type == VideoSourceType.localCamera) {
      if (first.isFrontCameraTest || second.isFrontCameraTest) {
        return first.isFrontCameraTest && second.isFrontCameraTest;
      }
      return true;
    }
    if (first.cameraId != null && second.cameraId != null) {
      return first.cameraId == second.cameraId;
    }
    return switch (first.type) {
      VideoSourceType.localCamera => true,
      VideoSourceType.rtsp => first.rtspUrl == second.rtspUrl,
      VideoSourceType.remotePhone => first.remoteBaseUrl == second.remoteBaseUrl,
      VideoSourceType.esp32 => first.remoteBaseUrl == second.remoteBaseUrl,
    };
  }
}
