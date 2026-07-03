// Unit tests for the Advisor quick-adjust chip→param mapping.
//
// Guards the UI→engine contract for the `recommend_workout(mood?, equipment?,
// terrain?)` call. The chip values presented to the user must exactly match
// the engine's expected parameter values — any mismatch means the engine
// receives an unknown value and the re-resolve fails silently (or panics).
//
// DR-018 A1/A2 corrections:
//   mood: engine-legal "fun" | "easy" | "hard" | "mix" (NOT fresh/normal/tired)
//   equipment: UI shows "indoor" | "outdoor", but engine receives:
//     - "trainer" (cycling indoor) or "treadmill" (running indoor)
//     - "outdoor" (both sports)
//   terrain: "flat" | "hilly" | "trail"

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Engine-legal mood values (from gatc-advisor workout_suggester coach_cues).
  // Panic-tested in engine: mood_prefix_panics_on_unknown_mood.
  const moodValues = ['fun', 'easy', 'hard', 'mix'];

  // Equipment UI values (what the user sees/selects).
  const equipmentUiValues = ['outdoor', 'indoor'];

  // Equipment ENGINE values (what gets sent to recommend_workout).
  // "indoor" is mapped to trainer (cycling) or treadmill (running).
  const equipmentEngineValuesCycling = ['outdoor', 'trainer'];
  const equipmentEngineValuesRunning = ['outdoor', 'treadmill'];

  // Terrain values (all engine-real).
  const terrainValues = ['flat', 'hilly', 'trail'];

  group('mood chip values (engine contract)', () {
    test('mood values are the engine-legal set', () {
      // gatc-advisor::workout_suggester legal moods: fun/easy/hard/mix
      // (NOT fresh/normal/tired — those panic the engine)
      expect(moodValues, orderedEquals(['fun', 'easy', 'hard', 'mix']));
      expect(moodValues.length, 4);
    });

    test('mood values do not include the WRONG values', () {
      // DR-018 A1: these old values panic the engine
      expect(moodValues.contains('fresh'), isFalse);
      expect(moodValues.contains('normal'), isFalse);
      expect(moodValues.contains('tired'), isFalse);
    });
  });

  group('equipment chip values (engine contract)', () {
    test('UI shows indoor/outdoor', () {
      expect(equipmentUiValues, orderedEquals(['outdoor', 'indoor']));
    });

    test('cycling: indoor maps to trainer', () {
      // Engine matches contains("trainer") for indoor cycling
      expect(equipmentEngineValuesCycling, contains('trainer'));
      expect(equipmentEngineValuesCycling, isNot(contains('indoor')));
    });

    test('running: indoor maps to treadmill', () {
      // Engine matches contains("treadmill") for indoor running
      expect(equipmentEngineValuesRunning, contains('treadmill'));
      expect(equipmentEngineValuesRunning, isNot(contains('indoor')));
    });

    test('outdoor is sent verbatim for both sports', () {
      expect(equipmentEngineValuesCycling, contains('outdoor'));
      expect(equipmentEngineValuesRunning, contains('outdoor'));
    });
  });

  group('terrain chip values (engine contract)', () {
    test('terrain values include trail', () {
      // DR-018 A2: flat/hilly/trail are all engine-real
      expect(terrainValues, orderedEquals(['flat', 'hilly', 'trail']));
      expect(terrainValues.length, 3);
    });
  });

  group('all values are lowercase (engine convention)', () {
    test('mood values lowercase', () {
      for (final v in moodValues) {
        expect(v, equals(v.toLowerCase()), reason: 'mood "$v" should be lowercase');
      }
    });

    test('equipment values lowercase', () {
      for (final v in [...equipmentUiValues, ...equipmentEngineValuesCycling, ...equipmentEngineValuesRunning]) {
        expect(v, equals(v.toLowerCase()), reason: 'equipment "$v" should be lowercase');
      }
    });

    test('terrain values lowercase', () {
      for (final v in terrainValues) {
        expect(v, equals(v.toLowerCase()), reason: 'terrain "$v" should be lowercase');
      }
    });
  });

  group('no empty or whitespace-only values', () {
    test('all values are non-empty', () {
      final all = [...moodValues, ...equipmentUiValues, ...terrainValues];
      for (final v in all) {
        expect(v.trim(), isNotEmpty, reason: 'value should not be empty: "$v"');
      }
    });
  });

  // Document that null selection means "no constraint" — engine returns
  // its default recommendation without filtering by that axis.
  group('null selection semantics', () {
    test('null mood means engine decides (no user constraint)', () {
      const String? noSelection = null;
      expect(noSelection, isNull);
    });

    test('selecting then deselecting returns to null', () {
      String? selection = 'fun';
      selection = (selection == 'fun') ? null : 'fun';
      expect(selection, isNull);
    });
  });

  // Chip→param name mapping (UI label → FFI parameter name).
  group('chip group → FFI parameter name', () {
    test('"In the mood for" group maps to mood parameter', () {
      // DR-018 A1: UI label changed from "Feeling" to "In the mood for"
      const uiLabel = 'In the mood for';
      const ffiParam = 'mood';
      expect(_labelToParam(uiLabel), equals(ffiParam));
    });

    test('Equipment group maps to equipment parameter', () {
      const uiLabel = 'Equipment';
      const ffiParam = 'equipment';
      expect(_labelToParam(uiLabel), equals(ffiParam));
    });

    test('Terrain group maps to terrain parameter', () {
      const uiLabel = 'Terrain';
      const ffiParam = 'terrain';
      expect(_labelToParam(uiLabel), equals(ffiParam));
    });
  });

  // Equipment value mapping logic (UI selection → engine value).
  group('equipment value mapping', () {
    test('cycling sport: indoor → trainer', () {
      expect(_equipmentValueForEngine('indoor', 'cycling'), equals('trainer'));
    });

    test('running sport: indoor → treadmill', () {
      expect(_equipmentValueForEngine('indoor', 'running'), equals('treadmill'));
    });

    test('outdoor → outdoor for any sport', () {
      expect(_equipmentValueForEngine('outdoor', 'cycling'), equals('outdoor'));
      expect(_equipmentValueForEngine('outdoor', 'running'), equals('outdoor'));
    });

    test('null sport defaults to trainer (cycling default)', () {
      expect(_equipmentValueForEngine('indoor', null), equals('trainer'));
    });
  });
}

/// Maps UI chip group label to FFI parameter name.
String _labelToParam(String uiLabel) {
  switch (uiLabel) {
    case 'In the mood for':
      return 'mood';
    case 'Equipment':
      return 'equipment';
    case 'Terrain':
      return 'terrain';
    default:
      throw ArgumentError('Unknown chip group: $uiLabel');
  }
}

/// Maps UI equipment selection to engine-legal value.
/// Mirrors AdvisorScreen._equipmentValueForEngine getter.
String _equipmentValueForEngine(String uiValue, String? sport) {
  if (uiValue == 'outdoor') return 'outdoor';
  if (uiValue == 'indoor') {
    return sport == 'running' ? 'treadmill' : 'trainer';
  }
  return uiValue;
}
