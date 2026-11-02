/// Diagnóstico conservador de ausência de snapshots VLC.
/// Um snapshot indica captura possível, não necessariamente quadro novo;
/// imagens estáticas são normais em câmeras de vigilância.
enum RtspFrameIssue { none, firstFrameTimeout, possibleFrameStall }

class RtspFrameWatchdogPolicy {
  const RtspFrameWatchdogPolicy({
    this.firstFrameTimeout = const Duration(seconds: 25),
    this.frameStallTimeout = const Duration(seconds: 18),
  });

  final Duration firstFrameTimeout;
  final Duration frameStallTimeout;

  RtspFrameIssue check({
    required DateTime now,
    required DateTime attachedAt,
    required DateTime? lastSuccessfulSnapshot,
  }) {
    if (lastSuccessfulSnapshot == null) {
      return now.difference(attachedAt) >= firstFrameTimeout
          ? RtspFrameIssue.firstFrameTimeout
          : RtspFrameIssue.none;
    }
    return now.difference(lastSuccessfulSnapshot) >= frameStallTimeout
        ? RtspFrameIssue.possibleFrameStall
        : RtspFrameIssue.none;
  }
}
