/// Relogio de exibicao monotônico para duracoes medidas pelo servico Android.
///
/// O status nativo continua sendo a fonte da verdade (consultado a cada 3 s),
/// enquanto a interface pode desenhar cada segundo sem fazer novas consultas.
/// A referencia so e reajustada quando a diferenca ultrapassa um segundo,
/// evitando oscilacao causada pelo atraso da rede e por arredondamentos.
class NativeElapsedCounter {
  int? _baseSeconds;
  Duration _sampledAt = Duration.zero;

  int? secondsAt(Duration now) {
    final base = _baseSeconds;
    if (base == null) {
      return null;
    }
    final elapsed = now - _sampledAt;
    return base + (elapsed.isNegative ? 0 : elapsed.inSeconds);
  }

  void synchronize({
    required bool active,
    required int? seconds,
    required Duration sampledAt,
  }) {
    if (!active) {
      _baseSeconds = null;
      return;
    }
    if (seconds == null) {
      return; // Status temporariamente incompleto; mantem contagem local.
    }
    final observed = seconds < 0 ? 0 : seconds;
    final predicted = secondsAt(sampledAt);
    if (predicted == null || (observed - predicted).abs() > 1) {
      _baseSeconds = observed;
      _sampledAt = sampledAt;
    }
  }
}
