// Public, testable model for an Advisor workout option.
//
// Parses the engine's `WorkoutOptionData` JSON
// (mivalta-rust-engine `gatc-types/src/lib.rs::WorkoutOptionData`, emitted by
// `AdvisorEngine::suggest_workouts`). Display-only: every field maps a verified
// engine field. Extracted from `advisor_screen.dart` so the engine→Dart JSON
// contract is unit-testable — the engine binding's private constructor makes the
// full screen un-mockable on the host test harness, so the parser is the
// testable seam.
//
// Field contract (verified against WorkoutOptionData):
//   option_id, title, zone, why, tags, structure.total_minutes,
//   target_watts (Option), target_pace_mss (Option, skip_serializing_if none).

/// Parsed workout option from engine JSON.
class WorkoutOption {
  final String optionId;
  final String title;
  final String zone;
  final String why;
  final List<String> tags;
  final int? durationMin;
  final int? targetWatts;
  final String? targetPaceMss;

  WorkoutOption({
    required this.optionId,
    required this.title,
    required this.zone,
    required this.why,
    required this.tags,
    this.durationMin,
    this.targetWatts,
    this.targetPaceMss,
  });

  factory WorkoutOption.fromJson(dynamic json) {
    if (json is! Map) {
      return WorkoutOption(
        optionId: '?',
        title: 'Unknown',
        zone: '?',
        why: '',
        tags: [],
      );
    }

    final structure = json['structure'];
    int? duration;
    if (structure is Map) {
      duration = (structure['total_minutes'] as num?)?.toInt();
    }

    return WorkoutOption(
      optionId: json['option_id']?.toString() ?? '?',
      title: json['title']?.toString() ?? 'Workout',
      zone: json['zone']?.toString() ?? '?',
      why: json['why']?.toString() ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      durationMin: duration,
      targetWatts: (json['target_watts'] as num?)?.toInt(),
      targetPaceMss: json['target_pace_mss']?.toString(),
    );
  }
}
