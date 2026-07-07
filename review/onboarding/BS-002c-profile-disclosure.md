STATUS: RULING — locked copy + layout (2026-07-07, walk round 2). Build in this batch.
# BS-002c — Sport step becomes "Your profile": disclosure pattern + multi-select

Supersedes BS-002b's sub-line for the Sport step. Bart's design, locked.
Rationale: ~95% of users want speed, ~5% want the architecture story — a
collapsible disclosure serves both without cluttering the screen.

## v2 COPY (Bart, 2026-07-07 17:35 walk — REPLACES the v1 copy below, verbatim)
**REDLINE: `review/onboarding/redlines/RL-profile-r1.html`** — both states
(collapsed + expanded) at 393×852, measured, with build notes. Build against
the redline; diff sim shot before it lands on the round-3 branch.
- Sub: **"MiValta builds a personal profile that becomes more accurate over
  time as it learns from and with you.\n\nEverything stays on your device.
  Never on a server."**
- Disclosure row label: **"Why we ask these questions"** (lock glyph +
  chevron unchanged).
- Expanded body, verbatim:
  **"Unlike most health and fitness apps, MiValta doesn't build your
  profile in the cloud. Your profile lives only on your device, where the
  AI runs locally and learns exclusively from the information you choose
  to provide.\n\nAs you use MiValta, it gradually builds a deeper
  understanding of you. Your sports, goals, training history, wearable
  data and your own feedback help create a profile that is uniquely
  yours. Because no two people are the same, your profile becomes
  increasingly personal over time.\n\nThe more information you choose to
  share, the better MiValta can understand your body, your habits and
  your progress. This allows it to provide more accurate insights,
  smarter recommendations and, if you choose, highly personalized
  training plans and coaching.\n\nYour health data, training history and
  personal profile are never uploaded to MiValta or any cloud service.
  Your account exists only to manage your email, membership and access
  to the app. Your personal profile always remains on your device.\n\n
  Your data remains yours. Always."**
- Step footer "On this phone. Never on a server." is now REDUNDANT with
  the sub's second line — REMOVE it on this step only (one-claim law);
  other steps keep theirs.
- Everything else per v1 below (question lead, caption, multi-select,
  disclosure mechanics).

## v1 — Locked layout & copy (step 1 of intake)
- Title: **"Your profile"**
- Sub (MivaltaType.body, textSecondary):
  **"MiValta builds a personal profile to understand you and personalize
  your training, recovery and insights.\n\nEverything stays on this device."**
- Disclosure row (below the sub, above the question): a lock glyph +
  **"How your private profile works"** + chevron ▾.
  MivaltaType.body, textSecondary; 44px min height; AnimatedSize expand
  (MivaltaMotion.standard); chevron rotates. NOT a generic dropdown — one
  intentional row. Collapsed by default.
- Expanded body (MivaltaType.small, textSecondary, verbatim):
  **"MiValta is built differently from most health and fitness apps.\n\n
  The AI runs entirely on your device. Your personal profile, health data
  and training history are never uploaded to MiValta or any cloud.\n\n
  The more information you choose to share — such as your sports, goals,
  training history and wearable data — the better MiValta understands you.
  Over time it learns from and with you, providing increasingly accurate
  insights, feedback and, if you choose, personalized training plans.\n\n
  You remain in control. You decide what to share, and your data always
  stays with you."**
- Question lead (after the disclosure, before the options):
  **"Let's start with your sports."** + caption **"Select all that apply."**
- Options: Running / Cycling — **MULTI-SELECT** (checkbox semantics, not
  radio). Verify `build_onboarding_profile` accepts multiple sports; if the
  engine takes one primary sport, the UI still multi-selects and passes the
  first as primary + rest as secondary IF the inputs contract has a field —
  otherwise log the gap honestly in the build report (engine ask), and keep
  single-select until it lands. DO NOT fake multi-select that silently
  drops data.
- Footer framing (from BS-002b — "about a minute / change later in You")
  moves INTO the sub? NO — drop the long framing sentence from this step;
  the disclosure now carries the depth. Keep only the step footer
  "On this phone. Never on a server." unchanged.

## Rule (extends BS-002b)
Depth is opt-in: the surface carries one short claim + one question;
architecture explanations live behind an intentional, labeled disclosure —
never stacked on the surface, never a separate screen.
