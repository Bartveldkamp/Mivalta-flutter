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
  final String? expression;

  /// Main-set opening cue (`structure.main_set.cue_start`). Parse-only add for
  /// the home "Today" card (dashboard removal Phase 2 — was SessionWidget.focus_cue).
  final String? focusCue;

  /// Card-sourced zone-purpose prose (`zone_purpose`), engine-owned (Phase 1).
  final String? zonePurpose;

  WorkoutOption({
    required this.optionId,
    required this.title,
    required this.zone,
    required this.why,
    required this.tags,
    this.durationMin,
    this.targetWatts,
    this.targetPaceMss,
    this.expression,
    this.focusCue,
    this.zonePurpose,
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
    String? cueStart;
    if (structure is Map) {
      duration = (structure['total_minutes'] as num?)?.toInt();
      // focus_cue = the main set's opening cue (display string, engine-authored).
      final mainSet = structure['main_set'];
      if (mainSet is Map) {
        cueStart = mainSet['cue_start']?.toString();
      }
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
      focusCue: cueStart,
      // zone_purpose: card-sourced prose now carried on the option (Phase 1).
      zonePurpose: json['zone_purpose']?.toString(),
      // Engine emits `expression` as an ExpressionData STRUCT
      // (gatc-types WorkoutOptionData.expression: Option<ExpressionData>,
      // fields expression_id/title/…), NOT a string. The badge renders the
      // field-facing title (e.g. "Hill Fartlek"), so extract `.title`.
      // (Previously unread → always null → the variation badge never showed:
      // a silent drop at the JSON seam.)
      expression: (json['expression'] is Map)
          ? (json['expression'] as Map)['title']?.toString()
          : null,
    );
  }

  /// BS-016 S3: Serialize option to JSON for realizeAdvisoryOffer.
  /// Note: This reconstructs the fields we have; the engine may accept partial data.
  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'title': title,
      'zone': zone,
      'why': why,
      'tags': tags,
      if (durationMin != null) 'structure': {'total_minutes': durationMin},
      if (targetWatts != null) 'target_watts': targetWatts,
      if (targetPaceMss != null) 'target_pace_mss': targetPaceMss,
      if (zonePurpose != null) 'zone_purpose': zonePurpose,
      if (expression != null) 'expression': {'title': expression},
    };
  }
}
