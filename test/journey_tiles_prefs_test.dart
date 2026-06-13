// Tests for JourneyTilesPrefs (§C.5 configurable tiles persistence).
// Same pattern as today_tiles_prefs_test.dart — round-trip through a temp dir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/copy/journey_labels.dart';
import 'package:mivalta_flutter/services/journey_tiles_prefs.dart';

void main() {
  group('JourneyTilesPrefs', () {
    late Directory tempDir;
    late JourneyTilesPrefs prefs;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('journey_tiles_test_');
      prefs = JourneyTilesPrefs(dir: tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('load returns defaults when no file exists', () async {
      final tiles = await prefs.load();
      expect(tiles, equals(kDefaultJourneyTiles));
    });

    test('save then load round-trips enabled tiles', () async {
      final enabled = {'learning', 'hrv', 'workouts'};
      await prefs.save(enabled);

      final loaded = await prefs.load();
      expect(loaded, equals(enabled));
    });

    test('load filters out unknown tile ids', () async {
      // Write a file with some unknown ids
      final file = File('${tempDir.path}/journey_tiles.json');
      await file.writeAsString('{"enabled":["learning","unknown_tile","hrv"]}');

      final loaded = await prefs.load();
      // Only known ids should be returned
      expect(loaded, equals({'learning', 'hrv'}));
    });

    test('load returns defaults for malformed JSON', () async {
      final file = File('${tempDir.path}/journey_tiles.json');
      await file.writeAsString('not valid json');

      final loaded = await prefs.load();
      expect(loaded, equals(kDefaultJourneyTiles));
    });

    test('load returns defaults for wrong JSON structure', () async {
      final file = File('${tempDir.path}/journey_tiles.json');
      await file.writeAsString('["learning", "hrv"]'); // Array instead of object

      final loaded = await prefs.load();
      expect(loaded, equals(kDefaultJourneyTiles));
    });

    test('load returns defaults when enabled is not a list', () async {
      final file = File('${tempDir.path}/journey_tiles.json');
      await file.writeAsString('{"enabled": "learning"}'); // String instead of list

      final loaded = await prefs.load();
      expect(loaded, equals(kDefaultJourneyTiles));
    });

    test('save preserves order from kJourneyTileIds', () async {
      // Save in a different order
      final enabled = {'adaptation', 'learning', 'fitness'};
      await prefs.save(enabled);

      // Read the raw file to verify order
      final file = File('${tempDir.path}/journey_tiles.json');
      final content = await file.readAsString();
      // The saved order should follow kJourneyTileIds
      expect(content, contains('"learning"'));
      expect(content, contains('"fitness"'));
      expect(content, contains('"adaptation"'));
      expect(content.indexOf('learning'), lessThan(content.indexOf('fitness')));
      expect(content.indexOf('fitness'), lessThan(content.indexOf('adaptation')));
    });
  });
}
