// DR-024 W2: Weather location model + storage tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/services/weather_location.dart';

void main() {
  group('WeatherLocation', () {
    test('none factory creates source=none location', () {
      const location = WeatherLocation.none;

      expect(location.source, WeatherLocationSource.none);
      expect(location.latitude, isNull);
      expect(location.longitude, isNull);
      expect(location.placeName, isNull);
      expect(location.hasCoordinates, isFalse);
    });

    test('manual factory creates source=manual location with coordinates', () {
      final location = WeatherLocation.manual(
        latitude: 52.3676,
        longitude: 4.9041,
        placeName: 'Amsterdam, Netherlands',
      );

      expect(location.source, WeatherLocationSource.manual);
      expect(location.latitude, 52.3676);
      expect(location.longitude, 4.9041);
      expect(location.placeName, 'Amsterdam, Netherlands');
      expect(location.hasCoordinates, isTrue);
    });

    test('gps factory creates source=gps location', () {
      final location = WeatherLocation.gps();

      expect(location.source, WeatherLocationSource.gps);
      expect(location.hasCoordinates, isFalse);
    });

    test('gps factory with cached coordinates', () {
      final location = WeatherLocation.gps(
        latitude: 51.5074,
        longitude: -0.1278,
        placeName: 'London, UK',
      );

      expect(location.source, WeatherLocationSource.gps);
      expect(location.latitude, 51.5074);
      expect(location.longitude, -0.1278);
      expect(location.placeName, 'London, UK');
      expect(location.hasCoordinates, isTrue);
    });

    test('toJson serializes correctly for none', () {
      const location = WeatherLocation.none;
      final json = location.toJson();

      expect(json['source'], 'none');
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
      expect(json.containsKey('placeName'), isFalse);
    });

    test('toJson serializes correctly for manual', () {
      final location = WeatherLocation.manual(
        latitude: 48.8566,
        longitude: 2.3522,
        placeName: 'Paris, France',
      );
      final json = location.toJson();

      expect(json['source'], 'manual');
      expect(json['latitude'], 48.8566);
      expect(json['longitude'], 2.3522);
      expect(json['placeName'], 'Paris, France');
    });

    test('toJson serializes correctly for gps', () {
      final location = WeatherLocation.gps();
      final json = location.toJson();

      expect(json['source'], 'gps');
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
    });

    test('fromJson deserializes none correctly', () {
      final json = {'source': 'none'};
      final location = WeatherLocation.fromJson(json);

      expect(location.source, WeatherLocationSource.none);
      expect(location.hasCoordinates, isFalse);
    });

    test('fromJson deserializes manual correctly', () {
      final json = {
        'source': 'manual',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'placeName': 'New York, USA',
      };
      final location = WeatherLocation.fromJson(json);

      expect(location.source, WeatherLocationSource.manual);
      expect(location.latitude, 40.7128);
      expect(location.longitude, -74.0060);
      expect(location.placeName, 'New York, USA');
      expect(location.hasCoordinates, isTrue);
    });

    test('fromJson deserializes gps correctly', () {
      final json = {'source': 'gps'};
      final location = WeatherLocation.fromJson(json);

      expect(location.source, WeatherLocationSource.gps);
    });

    test('fromJson handles unknown source gracefully', () {
      final json = {'source': 'unknown'};
      final location = WeatherLocation.fromJson(json);

      expect(location.source, WeatherLocationSource.none);
    });

    test('fromJson handles missing source gracefully', () {
      final json = <String, dynamic>{};
      final location = WeatherLocation.fromJson(json);

      expect(location.source, WeatherLocationSource.none);
    });

    test('round-trip serialization preserves data', () {
      final original = WeatherLocation.manual(
        latitude: 35.6762,
        longitude: 139.6503,
        placeName: 'Tokyo, Japan',
      );

      final json = original.toJson();
      final restored = WeatherLocation.fromJson(json);

      expect(restored.source, original.source);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.placeName, original.placeName);
    });
  });

  group('kMajorCities', () {
    test('contains expected cities', () {
      // Check that our curated list has the expected number of cities.
      expect(kMajorCities.length, greaterThan(40));

      // Check a few known cities exist.
      final names = kMajorCities.map((c) => c.$1).toList();
      expect(names, contains('Amsterdam, Netherlands'));
      expect(names, contains('New York, USA'));
      expect(names, contains('Tokyo, Japan'));
      expect(names, contains('Sydney, Australia'));
    });

    test('all cities have valid coordinates', () {
      for (final city in kMajorCities) {
        final name = city.$1;
        final lat = city.$2;
        final lon = city.$3;

        expect(lat, inInclusiveRange(-90.0, 90.0),
            reason: '$name has invalid latitude $lat');
        expect(lon, inInclusiveRange(-180.0, 180.0),
            reason: '$name has invalid longitude $lon');
      }
    });

    test('all cities have non-empty names', () {
      for (final city in kMajorCities) {
        expect(city.$1.isNotEmpty, isTrue,
            reason: 'City at (${city.$2}, ${city.$3}) has empty name');
      }
    });
  });
}
