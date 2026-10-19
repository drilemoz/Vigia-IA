import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/vehicle_capture_service.dart';

Detection found(String label, {double x = 0.4, double confidence = 0.9}) =>
    Detection(
      label: label,
      displayLabel: label,
      confidence: confidence,
      box: NormalizedBox(
        xMin: x,
        yMin: 0.3,
        xMax: x + 0.14,
        yMax: 0.65,
      ),
    );

void main() {
  test('fotografa automóvel após duas confirmações, mas não pessoa', () {
    final guard = VehicleCaptureGuard();
    final start = DateTime(2026, 10, 19);
    Detection? at(int seconds, List<Detection> detections) => guard.observe(
          cameraId: 'cam-a',
          now: start.add(Duration(seconds: seconds)),
          detections: detections,
          cameraMoving: false,
        );
    expect(at(0, [found('car'), found('person')]), isNull);
    expect(at(1, [found('car')])?.label, 'car');
    expect(at(2, [found('car')]), isNull);
    expect(at(70, [found('car')])?.label, isNot('car')); // confirmação reinicia após lacuna
    expect(at(71, [found('car')])?.label, 'car');
  });

  test('movimento global e baixa confiança impedem fotografar', () {
    final guard = VehicleCaptureGuard();
    final start = DateTime(2026, 10, 19);
    expect(guard.observe(cameraId: 'b', now: start, detections: [found('truck', confidence: 0.4)], cameraMoving: false), isNull);
    expect(guard.observe(cameraId: 'b', now: start.add(const Duration(seconds: 1)), detections: [found('truck')], cameraMoving: true), isNull);
    expect(guard.observe(cameraId: 'b', now: start.add(const Duration(seconds: 2)), detections: [found('truck')], cameraMoving: false), isNull);
    expect(guard.observe(cameraId: 'b', now: start.add(const Duration(seconds: 3)), detections: [found('truck')], cameraMoving: false)?.label, 'truck');
  });

  test('limite por câmera, locais independentes e rótulos admitidos', () {
    final guard = VehicleCaptureGuard();
    final t = DateTime(2026, 10, 19);
    Detection? take(String id, int seconds, Detection detection) => guard.observe(
      cameraId: id, now: t.add(Duration(seconds: seconds)), detections: [detection], cameraMoving: false,
    );
    expect(take('a', 0, found('bus')), isNull);
    expect(take('a', 1, found('bus'))?.label, 'bus');
    expect(take('b', 1, found('motorcycle')), isNull);
    expect(take('b', 2, found('motorcycle'))?.label, 'motorcycle');
    expect(take('a', 3, found('bus', x: .1)), isNull);
    expect(take('a', 4, found('bus', x: .1)), isNull); // janela de 8 s
    expect(take('a', 15, found('bus', x: .1)), isNull);
    expect(take('a', 16, found('bus', x: .1))?.label, 'bus');
    expect(take('a', 20, found('bicycle')), isNull);
  });
}
