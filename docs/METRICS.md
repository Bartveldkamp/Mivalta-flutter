# MiValta — Metrics & Measurement

How we measure the business **without** surveilling the user inside the app.
Companion to [`DISTRIBUTION_AND_TIERS.md`](DISTRIBUTION_AND_TIERS.md).

> **Principle:** "No harvesting" does **not** mean "no metrics." It means our
> numbers come from the **app stores**, our **own billing**, and our **own
> website** — never from tracking a user inside the app or touching their
> health data.

---

## 0. Hard rule — the free tier requires no account

The free **Monitor** never requires an account, login, or signup. Identity is
requested **only** at the paid upgrade (Advisory or Coach), on the website,
where billing legitimately needs it. See [`TIERS.md`](TIERS.md) for the
canonical tier model.

Requiring an account to use an on-device, "your data never leaves your phone"
app would contradict the core promise — so it is a locked product rule, not a
default to revisit.

Consequence for metrics: we cannot (and will not) count free users by
identity. We count them by the stores' aggregate device numbers instead.

---

## 1. What we measure, and from where

| Question | Source | Precision |
|----------|--------|-----------|
| How many installed? | Play Console / App Store Connect (installs, downloads) | Exact (store-reported) |
| How many active users? | Store consoles (active devices, retention curves) | Good aggregate proxy |
| Store-listing conversion (views → install) | Store consoles | Exact |
| Upgrade funnel (pricing page → checkout → paid) | **Website** analytics (cookieless) + checkout | Exact on the web side |
| How many paid (Advisory/Coach)? | Our **billing** (Stripe/etc.) + Auth0 entitlement | Exact |
| Free → paid conversion | `paid subscribers ÷ active devices` | Numerator exact; denominator store-estimated |

The two numbers a business actually steers on — **retention** and **paid
conversion** — are both available this way, with no in-app tracking.

```
Conversion ≈  paid subscribers (exact, from billing)
              ─────────────────────────────────────
              active devices    (from store consoles)
```

---

## 2. The one blind spot: the in-app funnel middle

The stores give the **top** (installs); billing gives the **bottom** (paid).
What neither shows is the in-app middle — onboarding completion, paywall
views, in-app drop-off. We accept that blind spot by default rather than
instrument the app. If it ever becomes a real decision-blocker, the only
acceptable way to close it:

**Anonymous, aggregate, opt-in telemetry** — and only under all of:
- No health data, no profile data, ever.
- No account, no device fingerprint, no persistent user ID.
- Aggregate event counts only (e.g. "onboarding_completed"), self-hosted or a
  privacy-first processor (e.g. Aptabase) — never Firebase/GA-style harvesters.
- Opt-in or clearly disclosed, and declared in the Play Data-safety form.
- Accept the trade: any in-app network call forfeits the "app needs zero
  network permission" posture (see DISTRIBUTION_AND_TIERS §4).

Until then: **no in-app analytics.**

---

## 3. Launch recommendation

Ship with **no in-app analytics**:
1. **App stores** → reach, active devices, retention.
2. **Own billing + Auth0** → exact paid conversion.
3. **Cookieless website analytics** (Plausible / Fathom) on the pricing and
   upgrade pages → the conversion funnel, where it actually happens (the web).

This keeps the app a clean, zero-network, no-harvesting artifact while still
giving reach, retention, and conversion. Revisit §2 (anonymous in-app
telemetry) only if in-app drop-off becomes a genuine unknown worth the
privacy-posture trade.
