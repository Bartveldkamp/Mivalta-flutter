// DR-024 W1: Masthead widget — extracted for golden testing.
// DR-024 W5: Tune button added for Make-It-Yours customization sheet.
//
// Two-tier masthead — BS-002 (Bart-approved variant 1b).
// Row 1: Brand wordmark centered. Row 2: Start workout left, weather + tune right.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/weather_service.dart';
import '../../theme/tokens.dart';

/// Two-tier masthead for the Today screen.
///
/// Row 1: MiValta logo + wordmark, centered.
/// Row 2: "Start workout" left, weather slot + tune button right.
class TodayMasthead extends StatelessWidget {
  const TodayMasthead({
    super.key,
    required this.onStartWorkout,
    this.weather,
    this.onTune,
  });

  /// Callback when "Start workout" is tapped.
  final VoidCallback onStartWorkout;

  /// Current weather report (null = honest absence → render nothing).
  final WeatherReport? weather;

  /// Callback when tune button is tapped (W5 Make-It-Yours entry).
  final VoidCallback? onTune;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // horizontal = x4 (16) to align with module-card edges; top = 8
      padding: const EdgeInsets.fromLTRB(MivaltaSpace.x4, 8, MivaltaSpace.x4, 0),
      child: Column(
        children: [
          // ── Row 1 · brand masthead, centered ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/mivalta-logo.svg', width: 30, height: 30),
              const SizedBox(width: 10),
              Text(
                'MiValta',
                style: GoogleFonts.zenDots(
                  fontSize: 24,
                  letterSpacing: 0.24, // ~0.01em × 24
                  color: MivaltaColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: MivaltaSpace.x3), // 12px

          // ── Row 2 · action micro-row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // left · Start workout (labeled text-button, brand green)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onStartWorkout,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, size: 18, color: MivaltaColors.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Start workout',
                      style: MivaltaType.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MivaltaColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),

              // right · weather + tune button (W5)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WeatherSlot(weather: weather),
                  if (onTune != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTune,
                      child: const Icon(
                        Icons.tune,
                        size: 20,
                        color: MivaltaColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Weather slot — real OS-provided data if available, honest absence otherwise.
/// Rule 6: weather comes from Apple WeatherKit via the OS frame; on any failure
/// we render nothing (no icon, no forecast), never a fabricated condition.
class _WeatherSlot extends StatelessWidget {
  const _WeatherSlot({this.weather});

  final WeatherReport? weather;

  @override
  Widget build(BuildContext context) {
    if (weather != null) {
      final tempC = weather!.temperatureC.round();
      // The condition text is the OS-provided string, rendered VERBATIM — never
      // re-derived from the symbol (which fabricated "Sunny" for any symbol
      // outside a short dictionary). The icon is a best-effort glyph for a known
      // symbol; an unrecognised symbol shows no icon (honest absence), never a
      // fabricated sun. The real condition + temp still render.
      final icon = _iconForWeatherSymbol(weather!.symbol);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: MivaltaColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Text(
            '${weather!.condition} $tempC°',
            style: MivaltaType.small.copyWith(color: MivaltaColors.textSecondary),
          ),
        ],
      );
    }
    // Honest absence (Rule 6): no real weather → render nothing, never a
    // fabricated "Sunny 18°" placeholder.
    return const SizedBox.shrink();
  }

  /// Map a known WeatherKit symbol to a Material icon. An unrecognised symbol
  /// returns null — the caller shows no icon (honest absence), never a
  /// fabricated sun glyph. The OS condition text still renders alongside.
  IconData? _iconForWeatherSymbol(String symbol) {
    return switch (symbol.toLowerCase()) {
      'sun.max' || 'sun.max.fill' => Icons.wb_sunny,
      'cloud.sun' || 'cloud.sun.fill' => Icons.wb_cloudy,
      'cloud' || 'cloud.fill' => Icons.cloud,
      'cloud.rain' || 'cloud.rain.fill' => Icons.grain,
      'cloud.heavyrain' || 'cloud.heavyrain.fill' => Icons.water_drop,
      'cloud.snow' || 'cloud.snow.fill' => Icons.ac_unit,
      'cloud.bolt' || 'cloud.bolt.fill' => Icons.bolt,
      'moon' || 'moon.fill' => Icons.nightlight,
      'cloud.moon' || 'cloud.moon.fill' => Icons.nights_stay,
      _ => null,
    };
  }
}
