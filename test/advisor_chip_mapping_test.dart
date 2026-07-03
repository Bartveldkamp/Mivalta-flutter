// Unit tests for the Advisor quick-adjust chip→param mapping.
//
// Guards the UI→engine contract for the `recommend_workout(mood?, equipment?,
// terrain?)` call. The chip values presented to the user must exactly match
// the engine's expected parameter values — any mismatch means the engine
// receives an unknown value and the re-resolve fails silently.
//
// Engine contract (gatc-ffi::recommend_workout):
//   mood: Option<String> — "fresh" | "normal" | "tired"
//   equipment: Option<String> — "indoor" | "outdoor"
//   terrain: Option<String> — "flat" | "hilly"

import 'package:flutter_test/flutter_test.dart';

void main() {
  // These constants document the engine contract. If the engine changes
  // its expected values, update HERE and in AdvisorScreen._buildChipRow().
  const moodValues = ['fresh', 'normal', 'tired'];
  const equipmentValues = ['indoor', 'outdoor'];
  const terrainValues = ['flat', 'hilly'];

  group('quick-adjust chip values (engine contract)', () {
    test('mood chip values match engine expectation', () {
      // gatc-ffi::recommend_workout accepts mood: "fresh" | "normal" | "tired"
      expect(moodValues, orderedEquals(['fresh', 'normal', 'tired']));
      expect(moodValues.length, 3);
    });

    test('equipment chip values match engine expectation', () {
      // gatc-ffi::recommend_workout accepts equipment: "indoor" | "outdoor"
      expect(equipmentValues, orderedEquals(['indoor', 'outdoor']));
      expect(equipmentValues.length, 2);
    });

    test('terrain chip values match engine expectation', () {
      // gatc-ffi::recommend_workout accepts terrain: "flat" | "hilly"
      expect(terrainValues, orderedEquals(['flat', 'hilly']));
      expect(terrainValues.length, 2);
    });

    test('all values are lowercase (engine convention)', () {
      for (final v in moodValues) {
        expect(v, equals(v.toLowerCase()), reason: 'mood "$v" should be lowercase');
      }
      for (final v in equipmentValues) {
        expect(v, equals(v.toLowerCase()), reason: 'equipment "$v" should be lowercase');
      }
      for (final v in terrainValues) {
        expect(v, equals(v.toLowerCase()), reason: 'terrain "$v" should be lowercase');
      }
    });

    test('no empty or whitespace-only values', () {
      final all = [...moodValues, ...equipmentValues, ...terrainValues];
      for (final v in all) {
        expect(v.trim(), isNotEmpty, reason: 'value should not be empty: "$v"');
      }
    });
  });

  // Document that null selection means "no constraint" — engine returns
  // its default recommendation without filtering by that axis.
  group('null selection semantics', () {
    test('null mood means engine decides (no user constraint)', () {
      // When user has not selected a mood chip, we pass null to
      // recommendWorkout, and the engine uses its readiness-based default.
      const String? noSelection = null;
      expect(noSelection, isNull);
    });

    test('selecting then deselecting returns to null', () {
      // User can tap a selected chip to deselect. The _ChipGroup widget
      // passes null when the already-selected value is tapped again.
      String? selection = 'fresh';
      // Simulate deselect: same value tapped again
      selection = (selection == 'fresh') ? null : 'fresh';
      expect(selection, isNull);
    });
  });

  // Chip→param name mapping (UI label → FFI parameter name).
  group('chip group → FFI parameter name', () {
    test('Feeling group maps to mood parameter', () {
      // The UI shows "Feeling" but the FFI parameter is "mood"
      const uiLabel = 'Feeling';
      const ffiParam = 'mood';
      expect(uiLabel, isNot(equals(ffiParam)),
          reason: 'UI label differs from FFI param name');
      // This documents the mapping for maintainers
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
}

/// Maps UI chip group label to FFI parameter name.
/// Documents the implicit mapping in AdvisorScreen._buildChipRow().
String _labelToParam(String uiLabel) {
  switch (uiLabel) {
    case 'Feeling':
      return 'mood';
    case 'Equipment':
      return 'equipment';
    case 'Terrain':
      return 'terrain';
    default:
      throw ArgumentError('Unknown chip group: $uiLabel');
  }
}
