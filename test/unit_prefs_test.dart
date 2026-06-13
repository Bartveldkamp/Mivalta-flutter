// Tests for UnitPrefs (§D: metric/imperial preference persistence).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/services/unit_prefs.dart';

void main() {
  group('UnitPrefs', () {
    late Directory tempDir;
    late UnitPrefs prefs;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('unit_prefs_test_');
      prefs = UnitPrefs(dir: tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('load returns metric by default when no file exists', () async {
      final system = await prefs.load();
      expect(system, UnitSystem.metric);
    });

    test('save then load round-trips imperial', () async {
      await prefs.save(UnitSystem.imperial);
      final loaded = await prefs.load();
      expect(loaded, UnitSystem.imperial);
    });

    test('save then load round-trips metric', () async {
      await prefs.save(UnitSystem.metric);
      final loaded = await prefs.load();
      expect(loaded, UnitSystem.metric);
    });

    test('load returns metric for malformed JSON', () async {
      final file = File('${tempDir.path}/unit_prefs.json');
      await file.writeAsString('not valid json');

      final system = await prefs.load();
      expect(system, UnitSystem.metric);
    });

    test('load returns metric for wrong JSON structure', () async {
      final file = File('${tempDir.path}/unit_prefs.json');
      await file.writeAsString('["imperial"]'); // Array instead of object

      final system = await prefs.load();
      expect(system, UnitSystem.metric);
    });
  });

  group('Unit formatting helpers', () {
    test('formatDistance metric', () {
      expect(formatDistance(5.5, UnitSystem.metric), '5.5 km');
      expect(formatDistance(42.195, UnitSystem.metric), '42 km');
    });

    test('formatDistance imperial', () {
      // 5 km ≈ 3.1 mi
      expect(formatDistance(5.0, UnitSystem.imperial), '3.1 mi');
      // 42 km ≈ 26.1 mi
      expect(formatDistance(42.195, UnitSystem.imperial), '26 mi');
    });

    test('formatPace metric', () {
      // 5:30 per km = 330 sec
      expect(formatPace(330, UnitSystem.metric), '5:30 /km');
    });

    test('formatPace imperial', () {
      // 5:00 per km ≈ 8:03 per mi
      expect(formatPace(300, UnitSystem.imperial), '8:03 /mi');
    });

    test('formatSpeed metric', () {
      expect(formatSpeed(30.0, UnitSystem.metric), '30.0 km/h');
    });

    test('formatSpeed imperial', () {
      // 30 km/h ≈ 18.6 mph
      expect(formatSpeed(30.0, UnitSystem.imperial), '18.6 mph');
    });

    test('formatElevation metric', () {
      expect(formatElevation(1000.0, UnitSystem.metric), '1000 m');
    });

    test('formatElevation imperial', () {
      // 1000 m ≈ 3281 ft
      expect(formatElevation(1000.0, UnitSystem.imperial), '3281 ft');
    });

    test('formatWeight metric', () {
      expect(formatWeight(75.0, UnitSystem.metric), '75.0 kg');
    });

    test('formatWeight imperial', () {
      // 75 kg ≈ 165.3 lb
      expect(formatWeight(75.0, UnitSystem.imperial), '165.3 lb');
    });

    test('unit labels', () {
      expect(distanceUnit(UnitSystem.metric), 'km');
      expect(distanceUnit(UnitSystem.imperial), 'mi');
      expect(paceUnit(UnitSystem.metric), '/km');
      expect(paceUnit(UnitSystem.imperial), '/mi');
      expect(speedUnit(UnitSystem.metric), 'km/h');
      expect(speedUnit(UnitSystem.imperial), 'mph');
      expect(elevationUnit(UnitSystem.metric), 'm');
      expect(elevationUnit(UnitSystem.imperial), 'ft');
    });
  });
}
