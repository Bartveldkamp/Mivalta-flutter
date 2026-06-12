// Round 3 items 11+18: weather display widgets. Pure display — both take the
// already-parsed [WeatherReport]/[WeatherDay], never touch the platform
// channel, so widget tests pump them directly with seeded data.

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

/// The 7-day forecast that "drops down" when the app-bar condition icon is
/// tapped (founder item 11 form). Current conditions on top, then one calm
/// row per day: weekday · glyph · condition · high/low.
class WeatherForecastPanel extends StatelessWidget {
  const WeatherForecastPanel({super.key, required this.report});
  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (report.daily.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x3),
            for (final day in report.daily) _DayRow(day: day),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});
  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final parsed = DateTime.tryParse(day.date);
    // Weekday label only — calm row, the date itself is depth nobody asked for.
    final label = parsed == null ? day.date : DateFormat.E().format(parsed);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: textTheme.bodySmall
                  ?.copyWith(color: MivaltaColors.textMuted),
            ),
          ),
          Icon(
            weatherGlyph(day.symbol),
            size: 16,
            color: MivaltaColors.textSecondary,
          ),
          const SizedBox(width: MivaltaSpace.x2),
          Expanded(
            child: Text(
              day.condition,
              style: textTheme.bodySmall
                  ?.copyWith(color: MivaltaColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${day.highC.round()}° / ${day.lowC.round()}°',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
