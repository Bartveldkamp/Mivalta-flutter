STATUS: RULING — locked copy + layout (2026-07-07). Walk find, fix in this round's batch.
# BS-001b — Auth & Splash: sovereignty-first, never "quiet"

Witnessed on device (Bart, 11:37, fresh corridor). Two screens, one law.

## The positioning error (the real bug)
Auth headline reads **"One quiet account."** — WRONG position. "Quiet" is a
UX trait of the notifications, not the brand. MiValta's first positioning is
DATA SOVEREIGNTY: everything happens on the phone, data never leaves it,
and that is architecture, not a promise. The first words a new user reads
must say THAT.

## Auth screen — locked copy + layout (FINAL wording from Bart, 2026-07-07)
- Logo: the MiValta logo asset (NOT a generic fingerprint glyph if that's
  what renders — verify the asset), 64px, glow treatment as-is.
- Wordmark under it: Zen Dots, 28 (matches splash scale, min 24).
- Eyebrow (MivaltaType.label, textMuted, uppercase): **"PRIVATE BY DESIGN"**
- Headline (MivaltaType.title): **"Your body. Your data."**
- Sub (MivaltaType.body, textSecondary, three short lines, verbatim):
  **"MiValta runs entirely on this phone.
  Your account stores only your email and membership.
  Your health and training data is never connected to your account."**
- DELETE "One quiet account." everywhere it appears. Grep the repo for
  "quiet account" — zero hits after this fix.
- Buttons/Terms unchanged.

## Scope: the WHOLE auth flow, one scale (added 11:55 — email + code screens)
The email-entry and code-entry screens have the same defects: mark tiny
(~40px), all type below scale (footer ~12px, sub ~14px). Locked flow scale:
- Mark: 64px on EVERY auth-flow screen (landing, email, code) — and it must
  be the MiValta logo asset; the teal fingerprint-style glyph rendering now
  confirms a wrong/placeholder asset. Replace with assets/mivalta-logo
  everywhere in the flow.
- Screen title ("Enter your code"): MivaltaType.title — keep, it's the one
  correctly-sized element.
- Sub ("Sent to …"): MivaltaType.body (16), textSecondary — not smaller.
- Code boxes: 52px min height, digits MivaltaType.cardTitle scale.
- Footer honesty line: MivaltaType.small (13) textMuted, min 12 — and update
  its wording to match the locked account line ("Used to sign you in.
  Never for health data." is fine — keep, it already matches the law).
- "Resend in Ns": MivaltaType.small, textMuted.
Rule: no text below 12 anywhere in the auth flow; body copy never below 14.

## Splash — layout
- Logo: 96px (currently reads ~64 — too small for the only thing on screen).
- Wordmark: Zen Dots 32.
- Sub "Your body. Your data." (it belongs here too): MivaltaType.body,
  textSecondary, **MivaltaSpace.x3 gap** below the wordmark (currently
  cramped tight under it — give it air).
- Minimum display: hold splash ≥1.2s even if routing resolves faster (it
  currently flashes past — the brand moment needs a beat).

## Rule (extends BS-002a's one-claim law)
"Quiet" describes behavior (notifications, tone) — it may appear in
Settings copy where behavior is configured, never in brand/identity
surfaces (splash, auth, onboarding, store copy). Identity surfaces speak
sovereignty first, always.
