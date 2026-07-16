# BUILD REPORT — BS-016 Josi Voice Surfaces

**Spec:** DESIGN_BRIEF_2026-07-06_VOICE_AND_BACKUP.md (Part 1)
**Branch:** feature/bs016-josi-voice
**Status:** PARTIAL — blocked on FFI seams

## Summary

Four Josi coach-voice surfaces from the V6 design brief. Each returns a
`RealizedLine` JSON (`text`, `safety[]`, `degraded`, `degrade_reason`,
`why`, `purpose`).

## Surface Status

| Surface | Description | FFI Seam | Status |
|---------|-------------|----------|--------|
| S1 | Post-workout reaction | `realize_workout_reflection` | **BLOCKED** (seam not in shim) |
| S2 | State/readiness reaction | `realize_advisor_line` | **DONE** (TodayScreen headline) |
| S3 | Advisory offer line | `realize_advisory_offer` | **BLOCKED** (seam not in shim) |
| S3 | Advisory why/purpose disclosure | (uses WorkoutOption fields) | **DONE** |
| S4 | End-of-day summary | `realize_day_summary` | **BLOCKED** (seam not in shim) |

## Work Done

### RealizedLine Model Update

Extended `lib/models/realized_line.dart` to parse the full V6 contract:

```dart
class RealizedLine {
  final String text;           // Verbatim headline
  final List<String> safety;   // Always render
  final bool degraded;         // Informational only
  final String? degradeReason; // Telemetry only, never shown
  final String? why;           // S3 disclosure
  final String? purpose;       // S3 disclosure
}
```

### S2 Already Live

`realizeAdvisorLine` is wired on TodayScreen (line 304):
```dart
final realizedJson = await binding.realizeAdvisorLine(handle, date: dateStr);
data.realizedLine = RealizedLine.parse(realizedJson);
```

### S3 Why/Purpose Already Live

The Advisor screen (line 471-484) already displays:
- `option.why` — body text
- `option.zonePurpose` — expandable widget with "more/less" tap

These fields come from `WorkoutOption.fromJson()` parsing engine output.

## Blocked Items

The following FFI seams exist in the engine (per design brief) but are NOT
in the current Flutter shim at `rust/src/api.rs`:

| FFI Function | Purpose | Engine Rev |
|--------------|---------|------------|
| `realize_workout_reflection` | Post-workout coach reaction | TBD |
| `realize_advisory_offer` | Josi offer line for Advisor | TBD |
| `realize_day_summary` | End-of-day coach summary | TBD |

The design brief says "both engine/platform sides are BUILT and pushed"
but the current pin (`a579584`) only exposes `realize_advisor_line`.

### To Unblock

1. Verify the engine rev that exports the three new `realize_*` functions
2. Update `rust/Cargo.toml` to pin that rev
3. Add shim functions in `rust/src/api.rs` (pattern matches `realize_advisor_line`)
4. Run `flutter_rust_bridge_codegen` to regenerate bindings
5. Add Dart facade methods in `lib/rust_engine.dart`
6. Wire UI surfaces

## Verification

```
flutter analyze  → No issues found!
flutter test     → 269 tests passed
```

## DoD Checklist

- [x] RealizedLine model extended (why, purpose, degrade_reason)
- [x] S2 State/readiness already live
- [x] S3 why/purpose disclosure already live (via WorkoutOption)
- [ ] S1 Post-workout reaction (blocked: FFI seam)
- [ ] S3 Advisory offer line (blocked: FFI seam)
- [ ] S4 End-of-day summary (blocked: FFI seam)

---

*Updated: 2026-07-06*
