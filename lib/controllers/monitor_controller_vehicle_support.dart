part of 'monitor_controller.dart';

extension MonitorVehicleCounting on MonitorController {
  void _captureVehicleObservations(
    RgbFrame frame,
    List<Detection> detected,
    bool cameraMoving,
    int session,
  ) {
    if (!_vehicleCapture.enabled || !_aiEnabled ||
        _shouldDiscardFrameResult(session) ||
        !DetectionCadencePolicy.fresh(frame.capturedAt, DateTime.now(),
            DetectionCadencePolicy.urgentFrameMaxAge)) {
      return;
    }
    unawaited(_vehicleCapture.observe(
      frame: frame,
      detections: detected,
      cameraId: sourceConfig.cameraId ?? _sourceDisplayName,
      source: _sourceDisplayName,
      cameraMoving: cameraMoving,
      confidenceThreshold: math.max(_settings.confidenceThreshold, 0.65),
      storagePolicy: _settings.storagePolicy,
    ));
  }

  bool get vehicleCountingEnabled => _vehicleCountingEnabled;
  int get vehiclePassageCount => _vehiclePassageCounter.count;

  /// Protótipo temporário por sessão e por câmera, sem gravação em disco.
  /// Requer rastreamento e IA ligados; ativação consciente para câmera fixa.
  void setVehicleCountingEnabled(bool enabled) {
    _vehicleCountingEnabled = enabled && _aiEnabled && _trackingEnabled;
    _vehiclePassageCounter.reset();
    _notify();
  }

  void resetVehiclePassageCount() {
    _vehiclePassageCounter.reset();
    _notify();
  }

  void _observeVehiclePassages(List<TrackedDetection> active,
      DateTime time, bool cameraMoving) {
    if (_vehicleCountingEnabled && _aiEnabled && _trackingEnabled) {
      _vehiclePassageCounter.observe(active,
          now: time, cameraMoving: cameraMoving);
    }
  }
}
