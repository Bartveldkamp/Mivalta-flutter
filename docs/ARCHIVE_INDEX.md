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
| [`archive/MIVALTA_OVERVIEW.md`](archive/MIVALTA_OVERVIEW.md) | superseded 2026-06-20 | [`../README.md`](../README.md) |
| [`archive/DISTRIBUTION_AND_TIERS.md`](archive/DISTRIBUTION_AND_TIERS.md) | superseded 2026-06-20 | [`TIERS.md`](TIERS.md) |
| [`archive/UI_UX_DESIGN_IOS_ANDROID.md`](archive/UI_UX_DESIGN_IOS_ANDROID.md) | superseded 2026-06-20 | [`DESIGN_BUILD_SPEC.md`](DESIGN_BUILD_SPEC.md) §7 + rust-engine `UI_UX_DIRECTION.md` |
| [`archive/NEXT_UPDATE_V2_ADOPTIONS.md`](archive/NEXT_UPDATE_V2_ADOPTIONS.md) | superseded 2026-06-20 | [`NEXT_BUILD_BRIEF.md`](NEXT_BUILD_BRIEF.md) §F |
| [`archive/AUDIT_BRIEF_UPDATE.md`](archive/AUDIT_BRIEF_UPDATE.md) | superseded 2026-06-20 | [`AUDIT_REPORT_2026-06-14.md`](AUDIT_REPORT_2026-06-14.md) |
| [`archive/SIMULATOR_AUDIT_REPORT.md`](archive/SIMULATOR_AUDIT_REPORT.md) | core finding **fixed** (rust-engine #267/#268) | [`WU3_EVIDENCE_MATRIX.md`](WU3_EVIDENCE_MATRIX.md) |
| [`archive/MAC_BRIEF_ADVISOR_LEAD_A.md`](archive/MAC_BRIEF_ADVISOR_LEAD_A.md) | **shipped** 2026-06-20 | pinned by `test/advisor_*` tests |
| [`archive/MAC_BRIEF_MODEL_LEARNING_SURFACE.md`](archive/MAC_BRIEF_MODEL_LEARNING_SURFACE.md) | **shipped** 2026-06-20 | learning-status UI in `lib/` |
| [`archive/MAC_BRIEF_PRIVACY_TOGGLE.md`](archive/MAC_BRIEF_PRIVACY_TOGGLE.md) | **shipped** 2026-06-21 | "Pause personalization" toggle in `../lib/screens/settings_screen.dart` |
| [`archive/CONTINUITY_AND_MEMORY.md`](archive/CONTINUITY_AND_MEMORY.md) | concepts folded into canon | [`../CLAUDE.md`](../CLAUDE.md) + [`MVP1_BUILD_BRIEF.md`](MVP1_BUILD_BRIEF.md) |
| [`archive/DAY2_RUST_BRIDGE.md`](archive/DAY2_RUST_BRIDGE.md) | historical FRB-bringup spike | reference only — FRB binding is proven; see `../rust/` + `../lib/src/rust/` |

_Keep this table in sync when a doc is moved into `docs/archive/`._
