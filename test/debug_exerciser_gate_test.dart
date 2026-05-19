// Day-7 W4: lock the kDebugMode gate that hides the SourceTier debug
// entry point from release builds. The SpikeHome title's long-press
// handler at lib/main.dart wires `onLongPress: kDebugMode ? cb : null`,
// and `isDebugExerciserAvailable` (debug_swatch_exerciser.dart) must
// stay an identity over `kDebugMode` so the two gates can't drift.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/debug_swatch_exerciser.dart';

void main() {
  test('isDebugExerciserAvailable is an identity over kDebugMode', () {
    expect(isDebugExerciserAvailable, kDebugMode);
  });

  test(
    'SpikeHome long-press pattern: onLongPress is null when gate is false',
    () {
      // Mirrors `onLongPress: kDebugMode ? _openDebugExerciser : null`
      // from lib/main.dart. When the gate resolves false the callback
      // is null, so Flutter's GestureDetector has no handler to fire —
      // which is the exact wire shape a release build ships.
      GestureDetector buildTitle({required bool gate}) => GestureDetector(
            onLongPress: gate ? () {} : null,
            child: const Text('title'),
          );
      expect(buildTitle(gate: false).onLongPress, isNull);
      expect(buildTitle(gate: true).onLongPress, isNotNull);
    },
  );
}
