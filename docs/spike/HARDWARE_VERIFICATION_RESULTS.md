# Hardware verification — V10.1 spike close

> **Scaffold** — empty fields below. Filled during the founder's phone
> session against the Motorola Edge 60 and committed as the
> spike-close marker. Numbers come from the in-app telemetry overlay
> (`tap to copy` from the bottom of SpikeHome); swatch matches are
> visual confirmations on the Readiness screen after each Debug
> Swatch Exerciser button press.

Device:   Motorola Edge 60
Date:     <YYYY-MM-DD>
APK:      <SHA-256 — paste from `Build:` line of telemetry block, full 64 chars>

## V10.1 acceptance bar: TTFT < 10s

The Day-1 spike acceptance bar (per `docs/V10_1_FLUTTER_PERF_SPIKE.md`)
is **time-to-first-token (TTFT) < 10 s** on the Motorola Edge 60 for
the prompt "Should I train today?". Three independent runs:

Run 1: TTFT=<>ms, Total=<>ms, Peak=<>KB PSS
Run 2: TTFT=<>ms, Total=<>ms, Peak=<>KB PSS
Run 3: TTFT=<>ms, Total=<>ms, Peak=<>KB PSS

Verdict: PASS / FAIL

## SourceTier swatch exercise

After tapping each Debug Swatch Exerciser button in sequence, the
Readiness screen's section (e) should render the matching LOCKED
swatch + label. "Match" = a yes/no check the founder makes
visually against `lib/theme/source_tier.dart`'s kSourceTierColor map
(Medical `#2BD974`, Device `#00C6A7`, Partial `#E6872F`, Manual
`#878C8C`).

| Source       | Written (timestamp) | Swatch rendered | Match |
|---|---|---|---|
| polar_h10    |                     | Medical (A)     |       |
| oura         |                     | Device (B)      |       |
| apple_health |                     | Partial (C)     |       |
| manual       |                     | Manual (D)      |       |

## Notes

<founder fills — anything that surprised; deviations from the runbook;
follow-ups for MVP build week 1>
