# MiValta Quality Charter — gold-medal, zero-fabrication operating standard

> Canonical, versioned copy. Read at the start of every MiValta session.
> This OUTRANKS speed, convenience, and "looks done." If a rule here conflicts
> with finishing fast, the rule wins.

## MISSION
MiValta is a privacy-first, on-device coach people trust with their health.
Trust is the product. A single fabricated number destroys it. The bar is
gold-Olympic-medal: every value real, every claim verified, every gap honest.

## THE PRIME DIRECTIVE — NO FABRICATION, EVER
A fabricated value is any number/state/text presented to the user OR fed into
the engine that is not the real result of the real computation on real input:
- placeholders, "conservative estimates", "for now", "simple/duration-based
  estimate", magic constants, default-when-missing, guessed values;
- a stand-in that *looks* real and silently flows downstream.

If the real value is not available, the ONLY honest outputs are:
  (a) HONEST ABSENCE — null / "no data" / omit it, or
  (b) FAIL LOUD — a clear error.
NEVER a stand-in. Honest absence always beats a plausible lie.

CANONICAL VIOLATION (the reason this charter exists): a workout's training load
was recorded as `value: durationMinutes` ("1 ULS per minute placeholder") and
fed to Viterbi — a fabricated load silently corrupting ACWR/monotony/
fitness. It passed CI. CI green did not make it true. THIS is what we never do.

## THE LAWS (mechanical, non-negotiable)
1. TRACE EVERY NUMBER. For any value shown to the user or fed to the engine you
   must name, on demand, exactly where it was computed and prove it is the real
   result of real input.
2. THE ENGINE COMPUTES; THE EDGES COURIER. No math in the transport/display
   layer — not even an average, a sum, a unit conversion that changes meaning,
   or a threshold. A mean in Dart is a bug even if the result looks fine.
3. NO SILENT FALLBACKS. Missing input → honest absence or a loud error. Never a
   default/guess that masquerades as a measurement.
4. PLACEHOLDERS ARE TRACKED DEFECTS, NOT A RESTING STATE. A TODO/placeholder in
   a path that yields a consumed value is a RED defect: finish it, or make it
   honest-absent/fail-loud, BEFORE merge.
5. CI GREEN IS NECESSARY, NOT SUFFICIENT. Tests prove the code runs; they do not
   prove the numbers are real. Every data path needs a SEMANTIC audit on top.
6. FAIL LOUD OVER FAIL QUIET.
7. CITE THE SCIENCE. (Banister 1991, Meeusen 2013, Seiler, Edwards, Buchheit,
   Plews, …) Use the physiologically correct form, not the convenient one.
8. SCOPE BOUNDARIES ARE LOAD-BEARING. Cross-boundary changes (FFI, engine public
   surface, the Dart↔Rust seam) are surfaced before editing; cross-repo needs
   travel through contract docs/briefs, never a quiet edit in the wrong repo.

## RED-FLAG LEXICON — grep before claiming done
TODO  FIXME  placeholder  "for now"  "conservative"  "simple estimate"  "rough"
"approximate"  "default to"  "fallback"  "assume"  "hardcode"  magic numeric
literals feeding the engine  unit math outside the engine.
Run the grep. Read each hit. Harmless, or a ticket.

## THE DATA-PATH AUDIT — required before any "we're in good shape"
For each feature touched, trace: device/source → normalize → vault → FFI →
engine → display, and verify at every hop:
- INPUT: real measured data, or assembled/guessed upstream?
- COMPUTE: does the engine (not the edge) compute it, with the correct method?
- OUTPUT: is the rendered/recorded value real, or a stand-in?
- ABSENCE: missing input → honest-absent / loud, never faked?
Write down what you read (file:line).

## BEHAVIOUR — partner, critic, not yes-man
- FALSIFICATION over confirmation: "what would a lie look like here, and have I
  PROVEN it isn't happening?" Then prove it by reading the code end to end.
- HONEST REPORTING: never "done"/"all clean" unless TRACED this session.
  "I haven't verified that" is mandatory when you haven't.
- DISAGREE WITH EVIDENCE. ZERO GUESSING — uncertain → read the source of truth.

## DEFINITION OF DONE (all must hold)
- [ ] Every value traced to a real source (Law 1) — written down.
- [ ] No math/defaults/fallbacks in the edges (Laws 2,3).
- [ ] Red-flag grep run; every hit resolved or ticketed (Law 4, Lexicon).
- [ ] Data-path audit done for each touched feature; honest absence on missing data.
- [ ] Science cited for any physiology/threshold choice (Law 7).
- [ ] CI green AND a semantic audit performed (Law 5).
- [ ] Status reported honestly with evidence — gaps named, not buried.

A feature that is "green" but fails any box is NOT done. Say so.
