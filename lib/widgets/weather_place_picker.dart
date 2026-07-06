// DR-024 W2: Weather place picker.
//
// A bottom sheet for selecting the weather location. Three options:
//   1. None (honest absence) — default, no weather displayed
//   2. Manual place — select from a list of major cities
//   3. GPS (opt-in) — use device location (requires permission)
//
// No network calls — uses a curated static list of cities for on-device
// selection (aligns with the no-cloud rule). For MVP this is sufficient;
// a geocoding API could be added post-launch if needed.

import 'package:flutter/material.dart';

import '../services/weather_location.dart';
import '../theme/tokens.dart';

/// Shows a bottom sheet for selecting weather location.
///
/// Returns the selected [WeatherLocation], or null if dismissed.
Future<WeatherLocation?> showWeatherPlacePicker(BuildContext context) async {
  return showModalBottomSheet<WeatherLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MivaltaColors.surface1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(MivaltaRadii.lg)),
    ),
    builder: (context) => const _WeatherPlacePickerSheet(),
  );
}

class _WeatherPlacePickerSheet extends StatefulWidget {
  const _WeatherPlacePickerSheet();

  @override
  State<_WeatherPlacePickerSheet> createState() => _WeatherPlacePickerSheetState();
}

class _WeatherPlacePickerSheetState extends State<_WeatherPlacePickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  WeatherLocation? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final location = await WeatherLocationService.load();
    if (mounted) {
      setState(() => _currentLocation = location);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<(String name, double lat, double lon)> get _filteredCities {
    if (_searchQuery.isEmpty) return kMajorCities;
    final query = _searchQuery.toLowerCase();
    return kMajorCities.where((c) => c.$1.toLowerCase().contains(query)).toList();
  }

  void _selectNone() {
    Navigator.pop(context, WeatherLocation.none);
  }

  void _selectGPS() {
    Navigator.pop(context, WeatherLocation.gps());
  }

  void _selectCity((String name, double lat, double lon) city) {
    Navigator.pop(
      context,
      WeatherLocation.manual(
        latitude: city.$2,
        longitude: city.$3,
        placeName: city.$1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MivaltaColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            child: Text(
              'Weather location',
              style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textPrimary),
            ),
          ),

          // Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
            child: Column(
              children: [
                // None option
                _OptionTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide weather',
                  subtitle: 'Don\'t show weather on the home screen',
                  isSelected: _currentLocation?.source == WeatherLocationSource.none,
                  onTap: _selectNone,
                ),

                const SizedBox(height: MivaltaSpace.x2),

                // GPS option
                _OptionTile(
                  icon: Icons.my_location,
                  title: 'Use my location',
                  subtitle: 'Automatically detect location (requires permission)',
                  isSelected: _currentLocation?.source == WeatherLocationSource.gps,
                  onTap: _selectGPS,
                ),
              ],
            ),
          ),

          const SizedBox(height: MivaltaSpace.x4),

          // Divider with "or select a city" label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
            child: Row(
              children: [
                Expanded(child: Divider(color: MivaltaColors.textMuted.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x3),
                  child: Text(
                    'or select a city',
                    style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
                  ),
                ),
                Expanded(child: Divider(color: MivaltaColors.textMuted.withValues(alpha: 0.3))),
              ],
            ),
          ),

          const SizedBox(height: MivaltaSpace.x3),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
            child: TextField(
              controller: _searchController,
              style: MivaltaType.body.copyWith(color: MivaltaColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search cities...',
                hintStyle: MivaltaType.body.copyWith(color: MivaltaColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: MivaltaColors.textMuted),
                filled: true,
                fillColor: MivaltaColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MivaltaRadii.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MivaltaSpace.x4,
                  vertical: MivaltaSpace.x3,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          const SizedBox(height: MivaltaSpace.x3),

          // City list
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
              itemCount: _filteredCities.length,
              itemBuilder: (context, index) {
                final city = _filteredCities[index];
                final isSelected = _currentLocation?.source == WeatherLocationSource.manual &&
                    _currentLocation?.placeName == city.$1;
                return _CityTile(
                  name: city.$1,
                  isSelected: isSelected,
                  onTap: () => _selectCity(city),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? MivaltaColors.primaryGreen.withValues(alpha: 0.15) : MivaltaColors.surface2,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? MivaltaColors.primaryGreen : MivaltaColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: MivaltaSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MivaltaType.body.copyWith(
                        color: MivaltaColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: MivaltaColors.primaryGreen, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MivaltaSpace.x2,
            vertical: MivaltaSpace.x3,
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_city,
                color: isSelected ? MivaltaColors.primaryGreen : MivaltaColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: MivaltaSpace.x3),
              Expanded(
                child: Text(
                  name,
                  style: MivaltaType.body.copyWith(
                    color: isSelected ? MivaltaColors.primaryGreen : MivaltaColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: MivaltaColors.primaryGreen, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
