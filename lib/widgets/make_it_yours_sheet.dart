// DR-024 W5: Make It Yours — customization bottom sheet.
//
// Beta contents:
// - Show weather toggle (from W2 preference)
// - Words/Numbers first toggle (existing onboarding_detail pref)
// - Module list with show/hide switches (placeholder for now)
//
// Tapped from the tune button (Icons.tune) in masthead row 2.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/weather_location.dart';
import '../theme/tokens.dart';
import 'weather_place_picker.dart';

/// "Make it yours" customization sheet.
///
/// [screenName] is the title suffix (e.g. "Today", "Journey").
/// [onChanged] is called when any preference changes so the parent can rebuild.
class MakeItYoursSheet extends StatefulWidget {
  const MakeItYoursSheet({
    super.key,
    required this.screenName,
    this.onChanged,
  });

  final String screenName;
  final VoidCallback? onChanged;

  /// Show the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String screenName,
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: MivaltaColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MivaltaRadii.lg)),
      ),
      builder: (_) => MakeItYoursSheet(
        screenName: screenName,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<MakeItYoursSheet> createState() => _MakeItYoursSheetState();
}

class _MakeItYoursSheetState extends State<MakeItYoursSheet> {
  bool _showWeather = true;
  bool _showNumbers = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // W2 law: default OFF — weather requires explicit opt-in.
        _showWeather = prefs.getBool('show_weather') ?? false;
        final detail = prefs.getString('onboarding_detail') ?? 'simple';
        _showNumbers = detail == 'numbers';
        _loading = false;
      });
    }
  }

  /// DR-024 W5 round 2: Consent moment on toggle-on.
  ///
  /// Toggling OFF: just turn it off.
  /// Toggling ON: open the place picker FIRST. Weather only enables if the
  /// user selects a place (manual or GPS). Dismissing the picker or selecting
  /// "none" keeps weather off.
  Future<void> _onWeatherToggle(bool wantsOn) async {
    if (!wantsOn) {
      // Turning off — no consent needed.
      await _setShowWeather(false);
      return;
    }

    // Turning on — open the place picker for consent.
    if (!mounted) return;
    final location = await showWeatherPlacePicker(context);

    // User dismissed or selected "none" — don't enable weather.
    if (location == null || location.source == WeatherLocationSource.none) {
      return;
    }

    // User selected a place — save location and enable weather.
    await WeatherLocationService.save(location);
    await _setShowWeather(true);
  }

  Future<void> _setShowWeather(bool value) async {
    setState(() => _showWeather = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_weather', value);
    widget.onChanged?.call();
  }

  Future<void> _setShowNumbers(bool value) async {
    setState(() => _showNumbers = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboarding_detail', value ? 'numbers' : 'simple');
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MivaltaSpace.x4,
          MivaltaSpace.x4,
          MivaltaSpace.x4,
          MivaltaSpace.x6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MivaltaColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MivaltaSpace.x4),

            // Title
            Text(
              'Make it yours · ${widget.screenName}',
              style: MivaltaType.cardTitle.copyWith(
                color: MivaltaColors.textPrimary,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x4),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(MivaltaSpace.x4),
                  child: CircularProgressIndicator(
                    color: MivaltaColors.stateProductive,
                    strokeWidth: 2,
                  ),
                ),
              )
            else ...[
              // Show weather toggle — W2: locked honest copy.
              _ToggleRow(
                label: 'Show weather',
                // DR-024 W5 round 2: locked honest subtitle.
                subtitle: 'A forecast needs a place — type one, or use '
                    'approximate location. Keyless request, never a '
                    'commercial API; nothing else leaves the phone.',
                value: _showWeather,
                onChanged: _onWeatherToggle,
              ),

              const SizedBox(height: MivaltaSpace.x3),

              // Words/Numbers first toggle
              _ToggleRow(
                label: 'Numbers first',
                subtitle: 'Show metrics before prose',
                value: _showNumbers,
                onChanged: _setShowNumbers,
              ),

            ],
          ],
        ),
      ),
    );
  }
}

/// Toggle row widget for the sheet.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: MivaltaType.body.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: MivaltaType.small.copyWith(
                  color: MivaltaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MivaltaColors.primaryGreen,
          activeThumbColor: MivaltaColors.textPrimary,
        ),
      ],
    );
  }
}
