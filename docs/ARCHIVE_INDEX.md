# Archive index — what each archived doc was, and what to read instead

`docs/archive/` keeps superseded/shipped documents for **provenance** (audit trail,
"why did we decide X"). Nothing there is current. This index is the one-glance map
so you don't have to open each file to learn it's stale — read the **"Read instead"**
column.

> The layered doc system is intentional: **canonical** (live specs/rules) →
> **active** (`docs/` working docs) → **archived** (`docs/archive/`, with provenance).
> Archived files are not deleted; they are headed and indexed here.

| Archived doc | Status | Read instead |
|---|---|---|
| [`archive/MVP1_BUILD_BRIEF.md`](archive/MVP1_BUILD_BRIEF.md) | spent sealed brief; predates the #123 UI rebuild | [`READING_ORDER.md`](READING_ORDER.md) + [`DESIGN_BUILD_SPEC.md`](DESIGN_BUILD_SPEC.md) |
| [`archive/ENGINE_SURFACE_AND_FRONTEND_MAP.md`](archive/ENGINE_SURFACE_AND_FRONTEND_MAP.md) | superseded (pre-strip surface map) | [`FRONTEND_HANDOVER.md`](FRONTEND_HANDOVER.md) (canonical FE↔engine ref) |
| [`archive/FRONTEND_FLOW_AND_STORIES.md`](archive/FRONTEND_FLOW_AND_STORIES.md) | superseded (pre-strip flow/stories) | [`FRONTEND_HANDOVER.md`](FRONTEND_HANDOVER.md) + [`DESIGN_BUILD_SPEC.md`](DESIGN_BUILD_SPEC.md) |
| [`archive/ENGINE_BRIEF_WORKOUT_LOAD.md`](archive/ENGINE_BRIEF_WORKOUT_LOAD.md) | resolved-defect provenance (the `value:durationMinutes` fabrication) | the Charter in [`../CLAUDE.md`](../CLAUDE.md) + [`DESIGN_DATA_CONTRACT.md`](DESIGN_DATA_CONTRACT.md) |
| [`archive/FOUNDER_FEEDBACK_2026-06-12.md`](archive/FOUNDER_FEEDBACK_2026-06-12.md) | decision provenance (WeatherKit, Josi cards, dark-first…) | decisions folded into [`../CLAUDE.md`](../CLAUDE.md) |
| [`archive/AUDIT_REPORT_2026-06-14.md`](archive/AUDIT_REPORT_2026-06-14.md) | historical pre-update audit — point-in-time | current honest status in [`../README.md`](../README.md) |
| [`archive/WU3_EVIDENCE_MATRIX.md`](archive/WU3_EVIDENCE_MATRIX.md) | diagnosis-only "no-data panel" trace; finding **fixed** (rust-engine #267/#268) | current code + [`FRONTEND_HANDOVER.md`](FRONTEND_HANDOVER.md) §5 |
| [`archive/SIMULATOR_AUDIT_REPORT.md`](archive/SIMULATOR_AUDIT_REPORT.md) | core finding **fixed** (rust-engine #267/#268) | [`archive/WU3_EVIDENCE_MATRIX.md`](archive/WU3_EVIDENCE_MATRIX.md) |
| [`archive/CONTINUITY_AND_MEMORY.md`](archive/CONTINUITY_AND_MEMORY.md) | concepts folded into canon | [`../CLAUDE.md`](../CLAUDE.md) + [`FRONTEND_HANDOVER.md`](FRONTEND_HANDOVER.md) §6 |
| [`archive/DAY2_RUST_BRIDGE.md`](archive/DAY2_RUST_BRIDGE.md) | historical FRB-bringup spike (why flutter_rust_bridge) | reference only — FRB is proven; see `../rust/` + `../lib/src/rust/` |

_Keep this table in sync when a doc is moved into `docs/archive/`._
