// Tests for the RealizedLine parse model — the display-side courier for the
// engine's firewall-validated Josi line (gatc_ffi::realize_advisor_line). Pure
// parsing: no slot substitution, no formatting, no branching on safety content.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/realized_line.dart';

void main() {
  group('RealizedLine.parse', () {
    test('parses text, safety list, and degraded verbatim', () {
      const json = '{"text":"You\'re recovered today.",'
          '"safety":["Focus on active recovery today.","Keep it easy."],'
          '"degraded":false}';
      final line = RealizedLine.parse(json);
      expect(line.text, "You're recovered today.");
      expect(line.safety, [
        'Focus on active recovery today.',
        'Keep it easy.',
      ]);
      expect(line.degraded, isFalse);
    });

    test('empty safety array → empty list (not null)', () {
      final line = RealizedLine.parse('{"text":"x","safety":[],"degraded":true}');
      expect(line.safety, isEmpty);
      expect(line.degraded, isTrue);
    });

    test('missing fields degrade to honest defaults, never throw', () {
      final line = RealizedLine.parse('{}');
      expect(line.text, '');
      expect(line.safety, isEmpty);
      expect(line.degraded, isFalse);
    });
  });
}
