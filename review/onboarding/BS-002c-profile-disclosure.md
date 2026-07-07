STATUS: RULING — locked copy + layout (2026-07-07, walk round 2). Build in this batch.
# BS-002c — Sport step becomes "Your profile": disclosure pattern + multi-select

Supersedes BS-002b's sub-line for the Sport step. Bart's design, locked.
Rationale: ~95% of users want speed, ~5% want the architecture story — a
collapsible disclosure serves both without cluttering the screen.

## Locked layout & copy (step 1 of intake)
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
