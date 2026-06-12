// Shared on-tap workout detail page — loads `get_workout_detail(date)` on
// demand and renders the shared WorkoutDetailCard.
//
// Display-only (founder feedback 2026-06-12 item 2): the engine owns every
// value; this page only fetches + parses defensively. Used from both the
// home's latest-workout row (ReadinessScreen) and the Explore history list.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/workout_detail.dart';
import '../rust_engine.dart';
import '../theme/tokens.dart';
import '../widgets/analytics/workout_detail_card.dart';

class WorkoutDetailPage extends StatelessWidget {
  const WorkoutDetailPage({
    super.key,
    required this.binding,
    required this.handle,
    required this.date,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('Workout'),
      ),
      body: FutureBuilder<String>(
        future: binding.getWorkoutDetail(handle, date: date),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          Widget unavailable() => Center(
                child: Padding(
                  padding: const EdgeInsets.all(MivaltaSpace.x5),
                  child: Text(
                    'Workout detail unavailable.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: MivaltaColors.textMuted),
                  ),
                ),
              );
          if (snap.hasError || snap.data == null) {
            return unavailable();
          }
          // FL-5: parse defensively — engine schema drift (version skew vs the
          // pinned rev) would otherwise throw inside build() and show a red
          // screen. Degrade to the same "unavailable" state on parse failure.
          // The engine returns JSON `null` when no workout exists for the
          // date — treat that as unavailable too, not an empty card.
          final WorkoutDetail detail;
          try {
            final decoded = jsonDecode(snap.data!);
            if (decoded == null) return unavailable();
            detail = WorkoutDetail.fromJson(decoded);
          } catch (_) {
            return unavailable();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            child: WorkoutDetailCard(detail: detail),
          );
        },
      ),
    );
  }
}
