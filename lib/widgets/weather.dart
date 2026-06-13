// Round 3 items 11+18 + LAST-TWO item 24: weather display widgets. Pure
// display — they take the already-parsed [WeatherReport]/[WeatherDay], never
// touch the platform channel, so widget tests pump them directly with seeded
// data.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/weather_service.dart';
import '../theme/tokens.dart';

/// Fixed display dictionary: Apple SF-symbol name → Material glyph. Label
/// layer only (same pattern as the today-facts dictionaries) — no condition
/// logic is computed here, the OS already decided the symbol.
IconData weatherGlyph(String symbol) {
  final s = symbol.toLowerCase();
  if (s.contains('bolt') || s.contains('thunder')) return Icons.bolt;
  if (s.contains('snow') ||
      s.contains('sleet') ||
      s.contains('hail') ||
      s.contains('flurr')) {
    return Icons.ac_unit;
  }
  if (s.contains('rain') || s.contains('drizzle') || s.contains('shower')) {
    return Icons.water_drop_outlined;
  }
  if (s.contains('fog') ||
      s.contains('haze') ||
      s.contains('smoke') ||
      s.contains('dust')) {
    return Icons.blur_on;
  }
  if (s.contains('wind')) return Icons.air;
  if (s.contains('cloud')) return Icons.cloud_outlined;
  if (s.contains('moon')) return Icons.nightlight_outlined;
  if (s.contains('sun')) return Icons.wb_sunny_outlined;
  return Icons.cloud_outlined;
}

/// The semi-opaque solid under the glass blur — §15.5's MANDATORY fallback,
/// painted ALWAYS (not conditionally): where blur is unavailable the surface
/// still reads as an intentional solid, never broken.
final Color kWeatherGlassFill = MivaltaColors.surface1.withAlpha(217);

/// LAST-TWO item 24: the GLASSY week overlay. Floats OVER the home (the main
/// screen stays visible beneath); swipe horizontally day-by-day.
///
/// Glass per UI_UX §15.5 [LOCKED]: this is the ONE glass surface region —
/// a single [BackdropFilter] (never nested), constant blur (never animated),
/// bound with [ClipRRect], with [kWeatherGlassFill] as the always-painted
/// solid fallback.
class WeatherWeekOverlay extends StatefulWidget {
  const WeatherWeekOverlay({super.key, required this.report});
  final WeatherReport report;

  @override
  State<WeatherWeekOverlay> createState() => _WeatherWeekOverlayState();
}

class _WeatherWeekOverlayState extends State<WeatherWeekOverlay> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final report = widget.report;
    final days = report.daily;

    return ClipRRect(
      borderRadius: BorderRadius.circular(MivaltaRadii.lg),
      child: BackdropFilter(
        // Constant sigma — §15.5: never animated blur.
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: kWeatherGlassFill,
            borderRadius: BorderRadius.circular(MivaltaRadii.lg),
            border: Border.all(color: MivaltaColors.surface2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MivaltaSpace.x4,
            vertical: MivaltaSpace.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current conditions — slim header.
              Row(
                children: [
                  Icon(
                    weatherGlyph(report.symbol),
                    size: 18,
                    color: MivaltaColors.textSecondary,
                  ),
                  const SizedBox(width: MivaltaSpace.x2),
                  Expanded(
                    child: Text(
                      report.condition,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${report.temperatureC.round()}°',
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
              // The week, one day per page — honest: only the days the OS
              // returned, no fabricated rows.
              if (days.isNotEmpty) ...[
                const SizedBox(height: MivaltaSpace.x3),
                SizedBox(
                  height: 120,
                  child: PageView(
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [for (final day in days) _DayPage(day: day)],
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(
                          horizontal: MivaltaSpace.x1,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? MivaltaColors.primaryGreen
                              : MivaltaColors.surface2,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One swipeable day: weekday · glyph · condition · high/low.
class _DayPage extends StatelessWidget {
  const _DayPage({required this.day});
  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final parsed = DateTime.tryParse(day.date);
    // Weekday label only — calm page, the date itself is depth nobody asked
    // for.
    final label =
        parsed == null ? day.date : DateFormat.EEEE().format(parsed);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: MivaltaColors.textMuted,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x2),
        Icon(
          weatherGlyph(day.symbol),
          size: 28,
          color: MivaltaColors.textSecondary,
        ),
        const SizedBox(height: MivaltaSpace.x2),
        Text(
          day.condition,
          style: textTheme.bodySmall
              ?.copyWith(color: MivaltaColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MivaltaSpace.x1),
        Text(
          '${day.highC.round()}° / ${day.lowC.round()}°',
          style: textTheme.titleMedium,
        ),
      ],
    );
  }
}
