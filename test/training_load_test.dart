// Tests for the Training Load model (UI tests stripped in clean-out).
//
// Contract guard: maps VaultEngine::read_daily_loads JSON `[[date, load], ...]`.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/training_load.dart';

void main() {
  group('TrainingLoad.fromJson', () {
    test('parses serde tuple array [[date, load], ...]', () {
      final t = TrainingLoad.fromJson([
        ['2026-06-01', 120.0],
        ['2026-06-02', 0.0],
        ['2026-06-03', 200.5],
      ]);
      expect(t.days.length, 3);
      expect(t.isEmpty, isFalse);
      expect(t.days.first.date, '2026-06-01');
      expect(t.days.first.load, 120.0);
      expect(t.peak, 200.5);
    });

    test('also tolerates [{date, load}] objects', () {
      final t = TrainingLoad.fromJson([
        {'date': 'd1', 'load': 50},
      ]);
      expect(t.days.length, 1);
      expect(t.days.first.load, 50.0);
    });

    test('non-list / malformed → safe empty', () {
      expect(TrainingLoad.fromJson(null).isEmpty, isTrue);
      expect(TrainingLoad.fromJson('x').isEmpty, isTrue);
      expect(TrainingLoad.fromJson([42, 'bad']).isEmpty, isTrue);
      expect(TrainingLoad.fromJson([]).peak, 0);
    });
  });
}
