# MAC_BRIEF: Daily Coach's-Text Notification

**Status:** BLOCKED — requires dependency approval before implementation.

## Overview (NEXT_UPDATE_V2_ADOPTIONS A5)

One daily local notification — a morning state line from the engine, written
like a coach's text. No cloud push; purely local-only.

## Requirements

1. **Single daily notification** — morning, never more than one per day
2. **Engine state line** — the readiness headline/autocue from the engine
3. **Coach's text tone** — warm, personal, not robotic or dashboardy
4. **Default ON** — enabled by default, toggle in Settings
5. **Local only** — no cloud, no account, no server round-trips

## Flagged Dependency

**Package:** `flutter_local_notifications`
**Platform:** iOS + Android
**Required before:** Any notification implementation can proceed

### Why flagged

- Adds a new dependency to pubspec.yaml
- Requires native permissions (iOS notification prompt, Android channel setup)
- Founder decision required on dependency policy

### To proceed

1. Founder approves adding `flutter_local_notifications` dependency
2. Add to `pubspec.yaml`
3. Configure iOS entitlements and Android notification channel
4. Implement `NotificationService` with morning scheduling
5. Wire to Settings toggle
6. Test on device (not simulator — notifications need real device)

## Copy draft (founder review)

The notification text should read like a coach texting in the morning:

- "Ready for a solid session today — 78, productive state."
- "Take it easy today — 52, still recovering from yesterday's effort."
- "Low data this week — log a few sessions and I'll dial in."

Exact copy goes through founder review.

## Implementation notes

- Schedule at user's preferred morning time (default 7:00 AM local)
- Cancel/reschedule if app opens before notification fires
- Respect system Do Not Disturb / Focus modes
- No sound by default; badge optional (iOS)

---

**Blocked until:** Dependency approval from founder.
