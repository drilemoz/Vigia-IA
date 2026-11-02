/// Politica conservadora de reconexao RTSP. Nao inicia players nem faz I/O.
/// O limite e de falhas consecutivas; confirmar quadro reinicia a sequencia.
class RtspRecoveryPolicy {
  RtspRecoveryPolicy({
    this.delays = const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
  });

  final List<Duration> delays;
  int _attempts = 0;

  int get attempts => _attempts;
  int get limit => delays.length;
  bool get exhausted => _attempts >= limit;

  /// Retorna null quando o limite foi atingido. Somente contabiliza quando
  /// uma tentativa de recuperacao for realmente agendada.
  Duration? scheduleNext() {
    if (exhausted) return null;
    return delays[_attempts++];
  }

  /// Reinicia o limite apenas quando um quadro real foi decodificado.
  void confirmedFrame() => _attempts = 0;
}
