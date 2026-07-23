// LEVELS LAW source guard (founder, ABSOLUTE) — the Flutter companion to the
// rust-engine `scripts/levels_guard.sh`, named in that script's header ("Flutter
// surfaces by the companion Flutter guard") but never built until now.
//
// The law: the athlete-facing rendering of an engine zone code must LEAD with
// the metabolic level, the code riding NESTED ("Aerobic endurance · Z2"). In
// Flutter that rendering flows through ONE choke point —
// `zoneDisplayLabel` / `zoneDisplayNameAndColor` in lib/theme/zone_names.dart —
// which sources its words from the engine-owned `kMetabolicLevelLabels`
// (the Dart mirror of `gatc_types::METABOLIC_LEVEL_LABELS`). The rendered
// OUTPUT is pinned by test/zone_names_test.dart; THIS guard protects the
// choke point itself, catching any surface that bypasses it.
//
// Two mechanical checks:
//   1. The divergent per-zone vocabulary file (lib/copy/zone_labels.dart) —
//      removed in the 2026-07-18 unification — stays deleted. There is exactly
//      ONE athlete vocabulary now.
//   2. No production Dart file (other than the choke point) passes a BARE zone
//      code (Z1..Z8, R, "Zone N") straight into a Text()/label. A bare leading
//      code is precisely the LEVELS LAW violation; all zone display must route
//      through `zoneDisplayLabel`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LEVELS LAW — Flutter source guard', () {
    test('the divergent per-zone vocabulary file stays deleted', () {
      expect(
        File('lib/copy/zone_labels.dart').existsSync(),
        isFalse,
        reason: 'lib/copy/zone_labels.dart is the removed divergent zone '
            'vocabulary (Recovery/Endurance/Neuromuscular/Max power). Do not '
            'reintroduce it — the one athlete vocabulary is the engine 6-level '
            'list, rendered via lib/theme/zone_names.dart.',
      );
    });

    test('no bare zone code is rendered directly in a Text()/label', () {
      // The choke point OWNS the code→label mapping — exempt it.
      const exempt = {'lib/theme/zone_names.dart'};
      // A bare code fronting a UI string: Text('Z4'), Text("R"), 'Zone 4'.
      final bareCode = RegExp(
        r'''Text\(\s*['"](Z[1-8]|R)['"]|['"]Zone\s*[1-8]['"]''',
      );

      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // Generated FRB bindings are not athlete copy.
        if (entity.path.contains('${Platform.pathSeparator}rust${Platform.pathSeparator}')) {
          continue;
        }
        if (entity.path.contains('/src/rust/')) continue;
        if (exempt.any(entity.path.endsWith)) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (bareCode.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Athlete-facing zone display must route through zoneDisplayLabel '
            '(level leads, code nested), never a bare code:\n'
            '${offenders.join('\n')}',
      );
    });
  });
}
