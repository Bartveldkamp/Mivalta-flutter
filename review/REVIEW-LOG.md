# REVIEW-LOG — MiValta Flutter Design Review Ledger

> Superseded BUILD-REPORTs + old witness shots live in [`_history/`](_history/README.md) (same subpaths). Live tree = specs + the active gate.

**Owner:** Claude Code
**Last updated:** 2026-07-04

---

## Structure

```
review/
├── REVIEW-LOG.md              ← this file (root only — never duplicate)
└── <surface>/                 ← today/, onboarding/, advisor/, etc.
    ├── BS-NNN-<surface>.md      ← ACTIVE build-steps spec (Design → Code)
    ├── SEED-NOTE.md / support   ← active support docs
    ├── BUILD-REPORT-<surface>-vN.md   ← Code writes after each build
    ├── <surface>_<SHA>_live.png       ← SHA-stamped screenshot
    └── archive/                 ← every superseded spec/review/report
```

---

## Conventions

### STATUS Header
Every file's **line 1** must be one of:
- `STATUS: ACTIVE`
- `STATUS: SUPERSEDED by <file>`
- `STATUS: CLOSED`

### One ACTIVE Spec Per Surface
Only the current `BS-NNN-<surface>.md` (and support docs) live in `<surface>/`. Everything superseded goes to `<surface>/archive/`.

### No Duplicates
Exactly one `REVIEW-LOG.md` at `review/` root. None inside surfaces.

### Spec-ID + SHA Handshake
Before building: "Executing `<spec-ID>` against SHA `<x>`"
Every build report's header names the spec it executed.

### ACTIVE Spec Wins
ACTIVE spec wins over any older DR fix-list. Never merge an old DR change into a newer BS.

### Screenshot Naming
`<surface>_<SHA>_live.png` — always SHA-stamped, always from live build.

---

## Active Surfaces

| Surface | Active Spec | Latest Build | SHA |
|---------|-------------|--------------|-----|
| today | BS-001-today.md | BUILD-REPORT-today-v6.md | `ee709d7` |
| journey | BS-015-journey.md | BUILD-REPORT-journey-v1.md | `bb2464a` |

---

## History

| Date | Action |
|------|--------|
| 2026-07-04 | Added Journey surface (BS-015), build-report-v1 @ bb2464a |
| 2026-07-01 | Established review/ structure, reconciled today/ |
