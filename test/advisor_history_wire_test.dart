// 2.1 advisor history wire — the Advisor surface calls the HISTORY-aware
// engine path, chips carried 1:1.
//
// The engine-side behaviour (system rotation from the 14-day window, dose
// progression, B5 calibration on a genuinely-empty history, baseline fallback
// on empty/balanced history) is proven by the engine's own seam test
// (gatc-ffi: recommend_workout_with_history_rotates_to_needed_system) — Dart
// must not re-prove engine logic (Law 2). What Dart owns, this pins:
//   1. the screen resolves options via recommendWorkoutWithHistory — the
//      stateless facade no longer exists, so a regression back to it cannot
//      even compile;
//   2. the mood chip value is couriered verbatim to the history call;
//   3. the engine's returned options render (courier out, engine in charge).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_option.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/screens/advisor_screen.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _RecordingBinding implements RustEngineBinding {
  final List<({String? mood, String? equipment, String? terrain})> historyCalls =
      [];

  @override
  Future<String> recommendWorkoutWithHistory(
    EnginesHandle handle, {
    String? mood,
    String? equipment,
    String? terrain,
  }) async {
    historyCalls.add((mood: mood, equipment: equipment, terrain: terrain));
    // Engine-shaped payload: bare array of options (H2 contract).
    return '''
    [{"option":"A","title":"Tempo intervals","zone":"Z3",
      "structure":{"total_minutes":45},"focus_cue":"steady rhythm"}]
    ''';
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

Widget _host(_RecordingBinding binding) => MaterialApp(
      home: AdvisorScreen(
        options: const <WorkoutOption>[],
        binding: binding,
        handle: _FakeHandle(),
      ),
    );

void main() {
  testWidgets('chip tap re-resolves via the HISTORY path, chip couriered 1:1',
      (tester) async {
    final binding = _RecordingBinding();
    await tester.pumpWidget(_host(binding));
    await tester.pump();

    // Tap the 'hard' mood chip → _reResolve must hit the history path.
    await tester.tap(find.text('Hard'));
    await tester.pump();
    await tester.pump();

    expect(binding.historyCalls, hasLength(1),
        reason: 'chip tap must resolve through recommendWorkoutWithHistory');
    expect(binding.historyCalls.single.mood, 'hard',
        reason: 'mood chip value couriered verbatim');
    // The engine-returned option renders (display-only courier out).
    expect(find.text('Tempo intervals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deselecting the chip re-resolves with mood null', (tester) async {
    final binding = _RecordingBinding();
    await tester.pumpWidget(_host(binding));
    await tester.pump();

    await tester.tap(find.text('Hard'));
    await tester.pump();
    await tester.tap(find.text('Hard')); // toggle off
    await tester.pump();

    expect(binding.historyCalls, hasLength(2));
    expect(binding.historyCalls.last.mood, isNull,
        reason: 'deselection couriers honest null, not a stale value');
  });
}
