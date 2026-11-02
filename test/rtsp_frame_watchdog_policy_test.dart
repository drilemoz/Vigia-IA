import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/rtsp_frame_watchdog_policy.dart';

void main() {
  const policy = RtspFrameWatchdogPolicy();
  final started = DateTime.utc(2026, 11, 2, 3);

  test('aguarda primeira captura por 25s mesmo quando VLC diz playing', () {
    expect(policy.check(now: started.add(const Duration(seconds: 24)),
      attachedAt: started, lastSuccessfulSnapshot: null), RtspFrameIssue.none);
    expect(policy.check(now: started.add(const Duration(seconds: 25)),
      attachedAt: started, lastSuccessfulSnapshot: null), RtspFrameIssue.firstFrameTimeout);
  });

  test('captura confirmada abre nova janela de 18 segundos', () {
    final lastFrame = started.add(const Duration(seconds: 20));
    expect(policy.check(now: started.add(const Duration(seconds: 37)),
      attachedAt: started, lastSuccessfulSnapshot: lastFrame), RtspFrameIssue.none);
    expect(policy.check(now: started.add(const Duration(seconds: 38)),
      attachedAt: started, lastSuccessfulSnapshot: lastFrame), RtspFrameIssue.possibleFrameStall);
  });

  test('janela reinicia com novo snapshot sem presumir movimento da cena', () {
    final latest = started.add(const Duration(seconds: 39));
    expect(policy.check(now: started.add(const Duration(seconds: 40)),
      attachedAt: started, lastSuccessfulSnapshot: latest), RtspFrameIssue.none);
  });
}
