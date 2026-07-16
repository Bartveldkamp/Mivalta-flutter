# MiValta — Tiers (canonical)

Product/pricing tiers — named, never numbered (the engine's "Tier 1/2/3"
in W1_SPEC = Viterbi/GATC/Josi is a *different* axis; don't conflate).

| Tier | Price | What the user gets | Josi | Engine |
|------|-------|--------------------|-----------|--------|
| **Monitor** | **Free** | Biometric numbers, stats, readiness/state — display only. No account. | ❌ | ViterbiEngine |
| **Advisory** | **Paid** | Monitor + Josi (explains, interactive) + a single-day training idea | ✅ | + AdvisorEngine + Josi |
| **Coach** | **Paid (higher)** | Advisory + full long-term periodized plan, adjusts on request | ✅ | + PlanEngine + ReplanEngine + Josi |

Ascending: Monitor → Advisory → Coach. Two paid price points; Coach is the top tier.
Josi switches on at Advisory and stays through Coach.

> **Beta Advisory Josi is the deterministic in-engine realizer** (no model;
> firewall-validated prose). The on-device LLM (model **W**) is a post-beta
> warmth upgrade that downloads at the first paid upgrade. The `Josi` column
> above is "✅ = Josi present," not "LLM present" — in beta she is deterministic.

**Consequences:**
- Free Monitor has **no Josi → no model download → genuinely zero network** (the app holds no INTERNET permission).
- The Josi model (**W**) downloads at the first paid upgrade (Advisory), via Play Asset Delivery.
- Entitlement **gating is future work** (arrives with accounts + website upgrade); today's build shows all tiers open.

---

## Distribution, the privacy boundary & entitlement

> *Folded in 2026-06-20 from the former `DISTRIBUTION_AND_TIERS.md` (since removed). How
> MiValta reaches users, how Josi is unlocked, and exactly where the on-device /
> no-harvesting line sits.*

**North star:** the engine DECIDES on-device; the cloud only ever knows *who you
are* (account) and *what you've paid for* (entitlement). Your health data never
leaves the phone. That is the whole product.

### The user journey

```
1. Install (free)        App Store / Google Play. Small download — the LLM is NOT in the app.
        │
2. Onboarding            Capture anchors (sport, FTP / threshold HR / pace, age…).
        │                Stored in the on-device encrypted vault. No account needed.
        │
3. Monitor (free)        Readiness, stats, state. On-device. No login, no cloud.
        │
4. (Optional) Account    Sign in with Auth0 — identity only (email).
        │
5. Upgrade to Advisory   On the WEBSITE: pick a plan, pay. Account is marked entitled.
        │                → Josi model (W) downloads via Play Asset Delivery.
        │
6. (Optional) Coach      Higher tier on the website. Full planning + replan unlocks.
        ▼
   Everything on-device, forever. Cloud is only touched for steps 4–6.
```

A user can stop at step 3 and have a complete, free, private coaching display.

### The privacy boundary (the part that must never blur)

| Stays on device (encrypted vault, never uploaded) | Touches the cloud (identity + billing only) |
|---|---|
| Biometrics (HR, HRV, sleep, SpO2) | Account email (Auth0) |
| Profile / anchors (age, sex, FTP, threshold) | Subscription tier / entitlement flag |
| Readiness, fatigue, all engine output | Payment (handled by a payment processor, not us) |
| Josi conversations + the model itself | — |

**No health data, profile data, or coaching output is ever sent to a server.**
The account exists only to answer one question: *"is this user entitled to Josi /
Coach?"* This is what lets us keep the "100% ownership, no harvesting" promise
while still having paid tiers and accounts.

### How the conversational AI model gets onto the device

The model (~1 GB) is too large to bundle in the app binary. **Play Asset
Delivery** ships it as an on-demand asset, delivered around install or on first
request. This lets the app declare **no runtime network permission of its own** —
the strongest privacy signal possible. The download is the Play Store *pushing a
file in*; the app never *sends* anything about the user out.

**Current status:** the free Monitor ships with **zero INTERNET permission** — the
app *cannot* reach any server. When the paid tiers go live, the model will be
delivered via Play Asset Delivery with no change to the app's network posture.

### Open decision — app-store purchase rules

Routing users to the **website** to pay (rather than in-app purchase) avoids the
15–30% store commission and keeps billing in our control — but Apple's and
Google's **anti-steering rules** restrict how an app may point users to outside
payment for digital features. This must be designed deliberately:

- **Safe pattern:** the app simply doesn't sell upgrades in-app. Advisory/Coach
  appear as "available on your plan" once the account is entitled; plan management
  lives entirely on the website, with no in-app "buy" button linking out.
- **Risky pattern:** an in-app "Upgrade — pay here →" button deep-linking to the
  web checkout. This is the kind of steering that has triggered rejections; rules
  are loosening (post-2024 rulings) but vary by region.

**Decision needed before store submission:** confirm the exact in-app
presentation of the upgrade with current Apple/Google policy (and whether to use
external-purchase entitlements where allowed). Until then, the app ships with **no
in-app purchase surface** and tier unlock is driven purely by the account
entitlement flag.

### Status

- ✅ Free Monitor — built, on-device, working (Android + iOS).
- ✅ On-device encrypted vault + crypto-erase data control.
- ✅ Zero network permission — app cannot reach any server.
- ⏳ Accounts (Auth0) — planned; not yet wired into the app flow.
- ⏳ Website tier upgrade + entitlement check — planned.
- ⏳ Conversational AI (model W) — in development; will ship via Play Asset
  Delivery gated on the entitlement flag.
- ⏳ App-store purchase-presentation decision — **open**.
- ⏳ Tier gating (Advisory/Coach engine features) — future work.
