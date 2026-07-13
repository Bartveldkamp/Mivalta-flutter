// PR-A — the lthr_bpm silent-loss fix, pinned.
//
// The engine's `build_onboarding_profile` accepts the HR threshold ONLY as
// `threshold_hr` (gatc-ffi OnboardingInputs, `#[serde(default)]`, no alias —
// traced 2026-07-13). Onboarding previously sent `lthr_bpm`, so serde
// defaulted the field to None and every typed HR threshold was silently
// dropped (charter law 3). These tests pin the contract keys so a key drift
// on either side fails HERE, not silently on an athlete's phone.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/screens/onboarding_screen.dart';

void main() {
  test('HR threshold travels under the engine-contract key threshold_hr', () {
    final inputs = thresholdAnchorInputs(
      thresholdHr: 165,
      sports: {'cycling'},
      ftpWatts: 240,
      thresholdPaceSecKm: null,
    );

    expect(inputs['threshold_hr'], 165,
        reason: 'the typed HR threshold must reach the engine verbatim');
    expect(inputs.containsKey('lthr_bpm'), isFalse,
        reason: 'lthr_bpm is NOT an engine key — serde silently dropped it '
            '(the 2026-07-13 silent-loss bug); it must never reappear');
    expect(inputs['ftp_watts'], 240);
  });

  test('unknown threshold stays honest null, never a stand-in', () {
    final inputs = thresholdAnchorInputs(
      thresholdHr: null,
      sports: {'running'},
      ftpWatts: null,
      thresholdPaceSecKm: 280,
    );

    expect(inputs.containsKey('threshold_hr'), isTrue,
        reason: 'key present with null = explicit "I don\'t know"');
    expect(inputs['threshold_hr'], isNull);
    expect(inputs['threshold_pace_sec_km'], 280);
    expect(inputs.containsKey('ftp_watts'), isFalse,
        reason: 'no cycling selected → no cycling anchor key');
  });

  test('sport gating: only selected sports contribute their anchor keys', () {
    final both = thresholdAnchorInputs(
      thresholdHr: 150,
      sports: {'cycling', 'running'},
      ftpWatts: 200,
      thresholdPaceSecKm: 300,
    );
    expect(both.keys.toSet(),
        {'threshold_hr', 'ftp_watts', 'threshold_pace_sec_km'});

    final neither = thresholdAnchorInputs(
      thresholdHr: 150,
      sports: <String>{},
      ftpWatts: 200,
      thresholdPaceSecKm: 300,
    );
    expect(neither.keys.toSet(), {'threshold_hr'},
        reason: 'HR threshold applies to all athletes; sport anchors are gated');
  });
}
