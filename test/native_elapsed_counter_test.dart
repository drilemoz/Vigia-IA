import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/native_elapsed_counter.dart';

void main() {
  group('NativeElapsedCounter', () {
    test('desenha cada segundo enquanto a consulta nativa ocorre a cada 3s', () {
      final counter = NativeElapsedCounter();
      counter.synchronize(active: true, seconds: 10, sampledAt: Duration.zero);
      expect(counter.secondsAt(Duration.zero), 10);
      expect(counter.secondsAt(const Duration(seconds: 1)), 11);
      expect(counter.secondsAt(const Duration(seconds: 2)), 12);
      counter.synchronize(
        active: true, seconds: 13, sampledAt: const Duration(seconds: 3));
      expect(counter.secondsAt(const Duration(seconds: 3)), 13);
      expect(counter.secondsAt(const Duration(seconds: 4)), 14);
    });

    test('tolerancia do status nao faz o relogio retroceder por 1 segundo', () {
      final counter = NativeElapsedCounter();
      counter.synchronize(active: true, seconds: 10, sampledAt: Duration.zero);
      counter.synchronize(
        active: true, seconds: 12, sampledAt: const Duration(seconds: 3));
      expect(counter.secondsAt(const Duration(seconds: 3)), 13);
    });

    test('ressincroniza desvio real e reconhece reinicio da gravacao', () {
      final counter = NativeElapsedCounter();
      counter.synchronize(active: true, seconds: 10, sampledAt: Duration.zero);
      counter.synchronize(
        active: true, seconds: 25, sampledAt: const Duration(seconds: 3));
      expect(counter.secondsAt(const Duration(seconds: 4)), 26);
      counter.synchronize(
        active: true, seconds: 0, sampledAt: const Duration(seconds: 5));
      expect(counter.secondsAt(const Duration(seconds: 6)), 1);
    });

    test('status ausente preserva relogio e parada limpa a contagem', () {
      final counter = NativeElapsedCounter();
      expect(counter.secondsAt(Duration.zero), isNull);
      counter.synchronize(active: true, seconds: 5, sampledAt: Duration.zero);
      counter.synchronize(
        active: true, seconds: null, sampledAt: const Duration(seconds: 2));
      expect(counter.secondsAt(const Duration(seconds: 3)), 8);
      counter.synchronize(
        active: false, seconds: 0, sampledAt: const Duration(seconds: 3));
      expect(counter.secondsAt(const Duration(seconds: 4)), isNull);
    });

    test('atraso na interface nao altera a duracao real', () {
      final counter = NativeElapsedCounter();
      counter.synchronize(active: true, seconds: 0, sampledAt: Duration.zero);
      expect(counter.secondsAt(const Duration(minutes: 2, seconds: 3)), 123);
    });
  });
}
