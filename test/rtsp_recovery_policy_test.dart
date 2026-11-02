import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/rtsp_recovery_policy.dart';

void main() {
  test('RTSP schedules bounded reconnections with backoff', () {
    final policy = RtspRecoveryPolicy();
    expect(policy.scheduleNext(), const Duration(seconds: 2));
    expect(policy.scheduleNext(), const Duration(seconds: 5));
    expect(policy.scheduleNext(), const Duration(seconds: 10));
    expect(policy.scheduleNext(), isNull);
    expect(policy.exhausted, isTrue);
    expect(policy.attempts, 3);
  });

  test('only confirmed image resets RTSP recovery budget', () {
    final policy = RtspRecoveryPolicy();
    expect(policy.scheduleNext(), const Duration(seconds: 2));
    policy.confirmedFrame();
    expect(policy.attempts, 0);
    expect(policy.scheduleNext(), const Duration(seconds: 2));
  });
}
