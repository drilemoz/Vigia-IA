import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/tracked_detection.dart';
import 'package:vigiaia/services/vehicle_passage_counter.dart';

TrackedDetection vehicle(int id, double x, {String label = 'car'}) =>
    TrackedDetection(
      trackId: id,
      detection: Detection(
        label: label,
        displayLabel: label,
        confidence: 0.95,
        box: NormalizedBox(
          xMin: x - 0.04,
          xMax: x + 0.04,
          yMin: 0.3,
          yMax: 0.6,
        ),
      ),
    );

void main() {
  test('conta uma passagem com dois quadros confirmados em cada lado', () {
    final counter = VehiclePassageCounter();
    final start = DateTime(2026, 10, 17);
    for (final entry in <(double, int)>[(0.20, 0), (0.28, 1), (0.72, 2), (0.78, 3)]) {
      counter.observe([vehicle(1, entry.$1)], now: start.add(Duration(seconds: entry.$2)), cameraMoving: false);
    }
    expect(counter.count, 1);
    counter.observe([vehicle(1, 0.25)], now: start.add(const Duration(seconds: 4)), cameraMoving: false);
    expect(counter.count, 1);
  });

  test('pessoa, bicicleta, centro e detecção isolada não geram passagem', () {
    final counter = VehiclePassageCounter();
    final start = DateTime(2026, 10, 17);
    counter.observe([vehicle(1, .1, label: 'person'), vehicle(2, .1, label: 'bicycle')], now: start, cameraMoving: false);
    counter.observe([vehicle(1, .9, label: 'person'), vehicle(2, .9, label: 'bicycle'), vehicle(3, .5)], now: start.add(const Duration(seconds: 1)), cameraMoving: false);
    expect(counter.count, 0);
  });

  test('movimento de câmera invalida pistas, mas conserva total confirmado', () {
    final counter = VehiclePassageCounter();
    final start = DateTime(2026, 10, 17);
    for (var i = 0; i < 4; i++) {
      counter.observe([vehicle(1, i < 2 ? .2 : .8)], now: start.add(Duration(seconds: i)), cameraMoving: false);
    }
    expect(counter.count, 1);
    counter.observe([vehicle(2, .2)], now: start.add(const Duration(seconds: 5)), cameraMoving: false);
    counter.observe([vehicle(2, .2)], now: start.add(const Duration(seconds: 6)), cameraMoving: true);
    counter.observe([vehicle(2, .8)], now: start.add(const Duration(seconds: 7)), cameraMoving: false);
    counter.observe([vehicle(2, .8)], now: start.add(const Duration(seconds: 8)), cameraMoving: false);
    expect(counter.count, 1);
    counter.reset();
    expect(counter.count, 0);
  });

  test('lacuna longa não conta falsa travessia', () {
    final counter = VehiclePassageCounter();
    final start = DateTime(2026, 10, 17);
    counter.observe([vehicle(3, .2)], now: start, cameraMoving: false);
    counter.observe([vehicle(3, .2)], now: start.add(const Duration(seconds: 1)), cameraMoving: false);
    counter.observe([vehicle(3, .8)], now: start.add(const Duration(seconds: 10)), cameraMoving: false);
    counter.observe([vehicle(3, .8)], now: start.add(const Duration(seconds: 11)), cameraMoving: false);
    expect(counter.count, 0);
  });
}
