# Design Brief 2026-07-06 — two changes that reach the UX

**From:** engine seat (branch `claude/mivalta-plan-model-eval-rtbsuq`)
**To:** design seat
**Scope:** (1) the four Josi coach-voice surfaces (V6) · (2) platform-backup
exclusion (Entry AM I-7)
**Status:** both engine/platform sides are BUILT and pushed; Flutter screen
work is what remains.

---

# Part 1 — Josi speaks like a coach: four voice surfaces (V6)

## Context

The engine now produces four Josi coach-voice surfaces (founder mandate
2026-07-06). Each returns one `RealizedLine` JSON:

```json
{ "text": "...", "safety": ["..."], "degraded": false,
  "degrade_reason": null, "why": "...", "purpose": "..." }
```

The contract is unchanged in spirit: **engine decides, Flutter displays** —
`text` renders verbatim, no paraphrase, no math, no thresholds in Dart.
Seam reference: rust-engine `docs/frontend/FFI_API_CONTRACT.md` §7.1. All
four run the same deterministic spine (card templates → slot substitution →
fidelity firewall → degrade-to-truth), so nothing Josi says can carry a
number the engine didn't produce.

## What's new per surface — and what design has to decide

### S1 — Post-workout reaction (`realize_workout_reflection`)

After any workout lands in the vault, Josi has a one-line coach reaction
("Solid work — 60 min of cycling, executed well where it counted."). Viterbi
grades the workout (HR decoupling, zone compliance, variability); the grade
selects the voice pool.

- **Natural home:** workout detail screen and/or the post-sync moment on
  Today.
- **Design decisions:** placement; whether it appears once (a moment) or
  persists on the detail view.
- **Note:** the *grade* (excellent…poor) is voiced, not exposed as a token.
  If design wants a visual grade chip/badge, that is a small follow-up
  engine seam — decide early.
- **Honest absence:** a workout without quality metrics gets a "logged, not
  judged" line. Do not design a grade slot that assumes a grade always
  exists.

### S2 — State/readiness reaction

Already live (the Today headline via `realize_advisor_line`). No change.

### S3 — Advisory presentation (`realize_advisory_offer`)

The Advisor screen's recommended workout now comes with a Josi offer line in
the readiness band's register, and — the big one — the **"why?" disclosure
tap now has real engine content**:

- `why` — the readiness-aware reason for this workout (card-templated,
  from the option itself);
- `purpose` — what the prescribed zone trains (`coach_cues:zone_purpose`).

These two fields map one-to-one onto the disclosure interaction already
locked in the Josi-as-presenter model.

- **Design decisions:** offer-line placement relative to the A/B/C options;
  disclosure layout for why + purpose.
- **Red days:** the advisor may return no options — design that state
  honestly (no invented fallback suggestion).

### S4 — End-of-day summary (`realize_day_summary`)

Entirely new moment: Josi closes the day. Three shapes — rest /
single-session / multi-session — derived from the vault's real activity
count; day load from Viterbi's own deduped ULS store.

- **Biggest open decision: where and when this lives** — an evening state
  of Today, the journey/history day view, a notification, or several. The
  engine has no clock; the client decides what "end of day" means and calls
  with the date.
- **Rest day is content, not an empty state:** a real line with
  deliberately zero numbers ("rest is training too").

## Locked constraints (not design-negotiable)

- `text` renders verbatim. `safety[]` strings must always render and may
  never be dropped or restyled into invisibility.
- `degraded: true` lines still render normally — the degrade IS the honest
  truth; no badge, no error styling. `degrade_reason` is telemetry, never
  shown.
- Josi remains a PRESENTER: no chat box, no text input, no TTS. The only
  interactions are the why-disclosure tap and choosing among suggestions
  (founder lock 2026-06-12).
- Lines rotate by calendar day and are bit-identical within a day —
  same-day re-renders are stable; don't cache across days.
- F1 no-data copy and source-tier color tokens are unchanged and still
  locked.

## Held / adjacent

- The tone-register onboarding question (analytical / emotional / elite) is
  plumbed end-to-end but held for founder sign-off — all current pools are
  register-neutral, so no tone UI yet.
- Flutter wiring for the three new seams is plain FRB-helper plumbing (no
  registry change, no FRB-regen); it lands with the post-#123 screen
  rebuild. Touchpoints: Today, workout detail, Advisor.

---

# Part 2 — Platform-backup exclusion: the UX it requires

**Companion code:** `ios/Runner/AppDelegate.swift`
(`excludeAppDataFromBackup`), `android/.../data_extraction_rules.xml` +
manifest attribute. **Canonical decision:** mivalta-rust-engine
`docs/DECISIONS.md` Entry AM, invariant I-7 — *platform backups are
vault-free*.

## What changed (invisible in the UI, load-bearing for the promise)

The app's data directory — the encrypted vault (`vault.db`), its key files
(`vault.key`, `cache.key`), and the ledger — is now **excluded from iCloud /
Finder backups on iOS and from Google cloud backup + device-to-device
transfer on Android**.

Why this is non-negotiable, in one paragraph: the vault's encryption key
lives on the device beside the ciphertext it protects. A platform backup
would carry **keys and ciphertext together**, so anyone holding the backup
holds the data — the encryption would buy nothing. It would also break the
crypto-erasure promise ("delete my data" destroys the key, making the vault
unrecoverable): a destroyed key survives inside every old backup. Excluding
the directory is what makes both promises true.

## The UX consequence design must own

**Health and training data does NOT come back with a phone restore.** When a
user restores a new phone from iCloud/Google backup, MiValta reinstalls but
starts EMPTY. This is correct behavior, not a bug — but to a user it looks
like data loss unless we set the expectation.

**The sanctioned migration path is the V5 encrypted vault export/import**
(passphrase-keyed, user-initiated, already in the engine: VaultEngine
export/import methods). Platform backup is never the migration path.

## Design decisions this opens

1. **"Moving to a new phone" flow.** Settings needs a clearly findable
   export action ("Take your data with you") framed as the way to move
   devices — a passphrase-protected file the user stores wherever they
   choose. And onboarding needs the import counterpart ("Restoring from an
   export?").
2. **Expectation-setting copy.** Somewhere honest and calm — likely the
   You/Settings privacy surface — the fact in plain words: "Your health data
   never leaves this device, and it is never in your phone backups. To move
   it to a new phone, use the encrypted export." This is a sovereignty
   FEATURE; the copy should carry it as one, not as a caveat.
3. **Deletion promise copy can now be stated fully.** "Delete my data"
   (crypto-erasure) is genuinely final — no backup copy survives. Design may
   state this plainly in the deletion confirmation; before this change that
   sentence would have been false on iOS.
4. **Empty-after-restore moment (edge, worth a decision).** A user who
   restored from a platform backup and opens MiValta sees a fresh app. Do we
   add a line to the fresh-start onboarding acknowledging it ("Restored your
   phone? Your MiValta data stays out of phone backups by design — import
   your encrypted export, or start fresh.")? Recommended, one sentence.

## Locked constraints

- No paraphrasing the promise into something softer or grander than the
  mechanism: excluded from platform backups; migrated only via encrypted
  export; deletion is final. Every claim above traces to shipped code.
- F1 no-data copy and all other locked copy remain untouched.
