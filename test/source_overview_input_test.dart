// PR-C3 — the provenance panel's marshal helpers, pinned against the engine
// contracts (list_data_sources census fields → build_source_overview's
// documented `{source: [metric, ...]}` input; metric labels are the ENGINE's
// vocabulary, traced 2026-07-13).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/screens/you_screen.dart';

void main() {
  test('census booleans project to the engine metric vocabulary verbatim', () {
    expect(
      metricLabelsFor({
        'has_hrv': true,
        'has_sleep': false,
        'has_resting_hr': true,
        'has_activity': true,
      }),
      ['hrv', 'resting_hr', 'activity'],
    );
    expect(metricLabelsFor({}), isEmpty,
        reason: 'absent booleans claim nothing');
  });

  test('overview input keeps only named sources with real capabilities', () {
    final input = sourceOverviewInput([
      {'source': 'polar_h10', 'has_hrv': true},
      {'source': 'oura', 'has_hrv': true, 'has_sleep': true},
      {'source': '', 'has_hrv': true}, // unnamed → dropped
      {'source': 'ghost'}, // no capabilities → dropped (absence, not a claim)
      'not-a-map', // malformed → dropped
    ]);

    expect(input, {
      'polar_h10': ['hrv'],
      'oura': ['hrv', 'sleep'],
    });
  });
}
