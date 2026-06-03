# MiValta — Distribution & Tiers

How MiValta reaches users, what's free, how Josi is unlocked, and exactly
where the on-device / no-harvesting line sits.

> **North star:** the engine DECIDES on-device; the cloud only ever knows
> *who you are* (account) and *what you've paid for* (entitlement). Your
> health data never leaves the phone. That is the whole product.

---

## 1. The tiers

| Tier | What you get | Where it runs | Cost |
|------|--------------|---------------|------|
| **Monitor** (free) | Readiness, fatigue state, workout advice (A/B/C), training context (ACWR / monotony / strain), data ingest from Health Connect / Apple Health / manual entry | 100% on-device (Rust engine) | **Free** |
| **Josi** (paid) | Conversational AI coach that *explains* the engine's decisions in natural language | 100% on-device (LLM runs locally) | Paid — upgraded via the **website** |

The Monitor is the whole coaching engine. Josi is the *messenger* on top of
it — it explains, it never decides. So the free tier is genuinely useful on
its own; Josi is an experience upgrade, not a gate on the coaching itself.

---

## 2. The user journey

```
1. Install (free)        App Store / Google Play. Small download — the LLM is NOT in the app.
        │
2. Onboarding            Capture anchors (sport, FTP / threshold HR / pace, age…).
        │                Stored in the on-device encrypted vault. No account needed.
        │
3. Monitor (free)        Coaching works immediately, on-device. No login, no cloud.
        │
4. (Optional) Account    Sign in with Auth0 — identity only (email).
        │
5. Upgrade to Josi       On the WEBSITE: pick a plan, pay. Account is marked entitled.
        │
6. Josi unlock           App sees the entitlement → fetches the Josi model ONCE
        │                → Josi then runs fully on-device, like everything else.
        ▼
   Everything on-device, forever. Cloud is only touched for steps 4–5.
```

A user can stop at step 3 and have a complete, free, private coach.

---

## 3. The privacy boundary (the part that must never blur)

| Stays on device (encrypted vault, never uploaded) | Touches the cloud (identity + billing only) |
|---|---|
| Biometrics (HR, HRV, sleep, SpO2) | Account email (Auth0) |
| Profile / anchors (age, sex, FTP, threshold) | Subscription tier / entitlement flag |
| Readiness, fatigue, all engine output | Payment (handled by a payment processor, not us) |
| Josi conversations + the model itself | — |

**No health data, profile data, or coaching output is ever sent to a
server.** The account exists only to answer one question: *"is this user
entitled to download Josi?"* This is what lets us keep the "100% ownership,
no harvesting" promise while still having paid tiers and accounts.

---

## 4. How the conversational AI model gets onto the device

The model (~1 GB) is too large to bundle in the app binary. **Play Asset
Delivery** ships it as an on-demand asset, delivered around install or on
first request. This lets the app declare **no runtime network permission of
its own** — the strongest privacy signal possible.

**Current status:** The free Monitor ships with **zero INTERNET permission**.
The app *cannot* reach any server. When the paid conversational AI tier goes
live, the model will be delivered via Play Asset Delivery — no change to the
app's network posture.

The download is the Play Store *pushing a file in*. The app never *sends*
anything about the user out.

---

## 5. Open decision — app-store purchase rules ⚠️

Routing users to the **website** to pay for Josi (rather than in-app
purchase) avoids the 15–30% store commission and keeps billing in our
control — but Apple's and Google's **anti-steering rules** restrict how an
app may point users to outside payment for digital features. This must be
designed deliberately:

- **Safe pattern:** the app simply doesn't sell Josi in-app. Josi appears as
  "available on your plan" once the account is entitled; plan management
  lives entirely on the website, with no in-app "buy" button linking out.
- **Risky pattern:** an in-app "Upgrade — pay here →" button deep-linking to
  the web checkout. This is the kind of steering that has triggered
  rejections; rules are loosening (post-2024 rulings) but vary by region.

**Decision needed before store submission:** confirm the exact in-app
presentation of the Josi upgrade with current Apple/Google policy (and
whether to use external-purchase entitlements where allowed). Until then,
the app ships with **no in-app purchase surface** and Josi unlock is driven
purely by the account entitlement flag.

---

## 6. Status

- ✅ Free Monitor — built, on-device, working (Android + iOS).
- ✅ On-device encrypted vault + crypto-erase data control.
- ✅ Zero network permission — app cannot reach any server.
- ⏳ Accounts (Auth0) — planned; not yet wired into the app flow.
- ⏳ Website tier upgrade + entitlement check — planned.
- ⏳ Conversational AI (model W) — in development; will ship via Play Asset
  Delivery gated on the entitlement flag.
- ⏳ App-store purchase-presentation decision (§5) — **open**.
