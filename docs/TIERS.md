# MiValta — Tiers (canonical)

Product/pricing tiers — named, never numbered (the engine's "Tier 1/2/3"
in W1_SPEC = Viterbi/GATC/Josi is a *different* axis; don't conflate).

| Tier | Price | What the user gets | Josi (LLM) | Engine |
|------|-------|--------------------|-----------|--------|
| **Monitor** | **Free** | Biometric numbers, stats, readiness/state — display only. No account. | ❌ | ViterbiEngine |
| **Advisory** | **Paid** | Monitor + Josi (explains, interactive) + a single-day training idea | ✅ | + AdvisorEngine + Josi |
| **Coach** | **Paid (higher)** | Advisory + full long-term periodized plan, adjusts on request | ✅ | + PlanEngine + ReplanEngine + Josi |

Ascending: Monitor → Advisory → Coach. Two paid price points; Coach is the top tier.
Josi switches on at Advisory and stays through Coach.

**Consequences:**
- Free Monitor has **no Josi → no model download → genuinely zero network** (the app holds no INTERNET permission).
- The Josi model (**W**) downloads at the first paid upgrade (Advisory), via Play Asset Delivery.
- Entitlement **gating is future work** (arrives with accounts + website upgrade); today's build shows all tiers open.
