STATUS: RULING — locked copy amendment (2026-07-06). Fix with BS-001a in P1.
# BS-002a — onboarding Promise step: one claim, said once

Witnessed on device (Bart, 16:11): the Promise screen stacks THREE privacy
paragraphs (intro claim + bolded claim + restore paragraph) — repetitive,
over-claiming, not next-generation. Confidence is restraint: say it once,
cleanly, and stop.

## ROUND 3 (device witness 2026-07-07 16:55 — layout defeated by glow-field padding)
Root cause, from source: `_buildPromiseGlow` centres a 76px mark inside a
245×245 field — ~85px invisible padding below the mark BEFORE the x5 gap,
so the title still floats low and the mark reads small. Fixes, exact:
1. Logo 76 → **96** (match splash; this is the brand cover of intake).
2. Glow must HUG the mark: `SizedBox` = logo size (96); render halos in an
   unclipped `Stack` (`clipBehavior: Clip.none`) via `Positioned` centred
   halos — blur may overflow, layout box may not. The x5 gap then measures
   from the VISUAL mark edge to the title — the whole point of the duo.
3. Cluster placement: not dead-centre — top-weighted like splash: column
   top-aligned, ~18% viewport top padding, so logo+title sit as one unit in
   the upper half and the lower half stays calm until the CTA.
4. **DELETE the restore link from this step** (Bart ruling): the import seam
   doesn't exist yet (BS-017 blocked) — a dead link on the first screen is
   dishonest. It returns with the real restore flow, on Auth, when the seam
   lands.
Asset note (closes the swap question): the fingerprint-wave IS the brand
mark — verified against assets/brand in the Design project. No swap needed;
size/position only.

## Locked copy (FINAL wording from Bart, 2026-07-07 11:59 walk) — replaces the block below
- Layout: title block moves UP to form a duo with the logo — logo, x5 gap,
  then the block (currently stranded mid-screen, too far from the mark).
  Not tighter than x5; the pair reads as one unit with air.
- Title (unchanged size): **"Your body.\nYour data."**
- Line 1 (MivaltaType.body, textSecondary): **"Private by design."**
- Line 2 (same style): **"Let's personalize MiValta to you."**
  (replaces "MiValta runs entirely on this phone. Nothing you enter ever
  leaves it." — that architecture claim now lives on the AUTH screen per
  BS-001b; the Promise step says it once as "Private by design." and moves
  the user forward.)
- Restore link (unchanged): "Restoring from an encrypted export?"
- CTA (unchanged): "Get started".
- The logo asset swap (BS-001b) applies here too.

## Locked copy (superseded 2026-07-07 — kept for history)
- Title (unchanged): **"Your body.\nYour data."**
- ONE sub line (MivaltaType.body, textSecondary, centered):
  "MiValta runs entirely on this phone. Nothing you enter ever leaves it."
- DELETE: "Everything is computed on your phone. We can't see it — and we
  built it that way. Let's set MiValta up for you."
- DELETE: "Nothing you enter here — or ever — leaves your phone. No server,
  no cloud. MiValta cannot read it."
- Restore: demote the paragraph to ONE quiet link-styled line
  (MivaltaType.small, textMuted, tappable):
  "Restoring from an encrypted export?"
  — no explanation sentence; the explanation lives behind the tap
  (BS-017 F4 sheet).
- CTA (unchanged): "Get started".

## Why
Three restatements of the same claim read as insecurity. One clean sentence
reads as fact. The per-step footer "On this phone. Never on a server."
(v3 §footers) continues to carry the promise through the rest of intake —
the Promise step doesn't need to pre-say it three times.

## Rule going forward (extends BS-001a's rule)
One privacy claim per screen, stated once. Detail lives behind a tap, never
stacked on the surface.
