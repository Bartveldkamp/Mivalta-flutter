// DR-024 W2: Weather location model and storage.
//
// Weather uses manual place by default (privacy-first). User can optionally
// enable coarse GPS for automatic location. The stored location is passed
// to WeatherKit instead of requesting live GPS every time.
//
// Privacy model:
//   - Default: no location stored, weather slot shows honest absence
//   - Manual: user selects a city/place, stored as lat/lon + name
//   - GPS opt-in: user explicitly enables GPS, location updated periodically
//
// Storage: SharedPreferences (weather location is UI preference, not vault data)

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Source of the weather location.
enum WeatherLocationSource {
  /// No location set — weather slot shows honest absence.
  none,

  /// User-selected manual place (lat/lon + name).
  manual,

  /// User opted into GPS-based location (coarse, ~1km accuracy).
  gps,
}

/// A stored weather location — either manual place or GPS opt-in flag.
class WeatherLocation {
  const WeatherLocation({
    required this.source,
    this.latitude,
    this.longitude,
    this.placeName,
  });

  final WeatherLocationSource source;

  /// Latitude (required for manual, populated by GPS when active).
  final double? latitude;

  /// Longitude (required for manual, populated by GPS when active).
  final double? longitude;

  /// Human-readable place name (e.g., "Amsterdam, Netherlands").
  final String? placeName;

  /// True if we have valid coordinates to fetch weather.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Create from JSON map (for SharedPreferences storage).
  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    final sourceStr = json['source'] as String? ?? 'none';
    final source = WeatherLocationSource.values.firstWhere(
      (s) => s.name == sourceStr,
      orElse: () => WeatherLocationSource.none,
    );
    return WeatherLocation(
      source: source,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeName: json['placeName'] as String?,
    );
  }

  /// Serialize to JSON map for storage.
  Map<String, dynamic> toJson() => {
        'source': source.name,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (placeName != null) 'placeName': placeName,
      };

  /// The default state: no location, weather shows honest absence.
  static const none = WeatherLocation(source: WeatherLocationSource.none);

  /// Create a manual place location.
  factory WeatherLocation.manual({
    required double latitude,
    required double longitude,
    required String placeName,
  }) =>
      WeatherLocation(
        source: WeatherLocationSource.manual,
        latitude: latitude,
        longitude: longitude,
        placeName: placeName,
      );

  /// Create a GPS opt-in location (coordinates populated on fetch).
  factory WeatherLocation.gps({
    double? latitude,
    double? longitude,
    String? placeName,
  }) =>
      WeatherLocation(
        source: WeatherLocationSource.gps,
        latitude: latitude,
        longitude: longitude,
        placeName: placeName,
      );

  @override
  String toString() =>
      'WeatherLocation($source, lat=$latitude, lon=$longitude, name=$placeName)';
}

/// Service for storing and retrieving the user's weather location preference.
class WeatherLocationService {
  static const _prefsKey = 'weather_location';

  /// Load the stored weather location, or [WeatherLocation.none] if not set.
  static Future<WeatherLocation> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return WeatherLocation.none;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return WeatherLocation.fromJson(map);
    } catch (_) {
      return WeatherLocation.none;
    }
  }

  /// Save the weather location.
  static Future<void> save(WeatherLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(location.toJson());
    await prefs.setString(_prefsKey, json);
  }

  /// Clear the stored location (revert to honest absence).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

/// A few major cities for the simple place picker.
/// Each entry: [name, latitude, longitude]
///
/// This is a curated list for MVP — a full geocoding API would be better
/// for production, but that requires a network call which conflicts with
/// the no-cloud rule. This static list is on-device only.
const kMajorCities = <(String name, double lat, double lon)>[
  // Europe
  ('Amsterdam, Netherlands', 52.3676, 4.9041),
  ('London, UK', 51.5074, -0.1278),
  ('Paris, France', 48.8566, 2.3522),
  ('Berlin, Germany', 52.5200, 13.4050),
  ('Madrid, Spain', 40.4168, -3.7038),
  ('Rome, Italy', 41.9028, 12.4964),
  ('Barcelona, Spain', 41.3851, 2.1734),
  ('Vienna, Austria', 48.2082, 16.3738),
  ('Munich, Germany', 48.1351, 11.5820),
  ('Brussels, Belgium', 50.8503, 4.3517),
  ('Zurich, Switzerland', 47.3769, 8.5417),
  ('Copenhagen, Denmark', 55.6761, 12.5683),
  ('Stockholm, Sweden', 59.3293, 18.0686),
  ('Oslo, Norway', 59.9139, 10.7522),
  ('Helsinki, Finland', 60.1699, 24.9384),
  ('Dublin, Ireland', 53.3498, -6.2603),
  ('Lisbon, Portugal', 38.7223, -9.1393),
  ('Athens, Greece', 37.9838, 23.7275),
  ('Prague, Czech Republic', 50.0755, 14.4378),
  ('Warsaw, Poland', 52.2297, 21.0122),

  // North America
  ('New York, USA', 40.7128, -74.0060),
  ('Los Angeles, USA', 34.0522, -118.2437),
  ('Chicago, USA', 41.8781, -87.6298),
  ('Toronto, Canada', 43.6532, -79.3832),
  ('San Francisco, USA', 37.7749, -122.4194),
  ('Seattle, USA', 47.6062, -122.3321),
  ('Boston, USA', 42.3601, -71.0589),
  ('Miami, USA', 25.7617, -80.1918),
  ('Denver, USA', 39.7392, -104.9903),
  ('Vancouver, Canada', 49.2827, -123.1207),
  ('Montreal, Canada', 45.5017, -73.5673),

  // Asia-Pacific
  ('Tokyo, Japan', 35.6762, 139.6503),
  ('Sydney, Australia', -33.8688, 151.2093),
  ('Singapore', 1.3521, 103.8198),
  ('Hong Kong', 22.3193, 114.1694),
  ('Seoul, South Korea', 37.5665, 126.9780),
  ('Melbourne, Australia', -37.8136, 144.9631),
  ('Auckland, New Zealand', -36.8509, 174.7645),
  ('Mumbai, India', 19.0760, 72.8777),
  ('Bangkok, Thailand', 13.7563, 100.5018),
  ('Dubai, UAE', 25.2048, 55.2708),

  // South America
  ('São Paulo, Brazil', -23.5505, -46.6333),
  ('Buenos Aires, Argentina', -34.6037, -58.3816),
  ('Rio de Janeiro, Brazil', -22.9068, -43.1729),
  ('Santiago, Chile', -33.4489, -70.6693),
  ('Lima, Peru', -12.0464, -77.0428),
  ('Bogotá, Colombia', 4.7110, -74.0721),

  // Africa
  ('Cape Town, South Africa', -33.9249, 18.4241),
  ('Cairo, Egypt', 30.0444, 31.2357),
  ('Nairobi, Kenya', -1.2921, 36.8219),
  ('Lagos, Nigeria', 6.5244, 3.3792),
];
