# BUILD REPORT — BS-017 Backup Sovereignty UX

**Spec:** DESIGN_BRIEF_2026-07-06_VOICE_AND_BACKUP.md (Part 2)
**Branch:** feature/bs017-backup-sovereignty
**Status:** DONE (import blocked on FFI seam)

## Summary

Platform-backup exclusion UX. The vault is excluded from iCloud/Google backup
(platform code done). This branch adds the user-facing surfaces:

1. Expectation-setting copy in sovereignty card
2. Encrypted vault export for device migration
3. Updated erase confirmation (no backup survives)

## Work Done

### 1. Sovereignty Card — Expectation-Setting Copy

Updated promise banner (lines 509-520 of you_screen.dart):

Before:
> "Computed on your phone. Your biometrics never leave this device."

After:
> "Your health data never leaves this device, and it is never in your phone
> backups. To move it to a new phone, use the encrypted export."

### 2. Encrypted Vault Export

New action in sovereignty card:
- **Label:** "Take your data with you"
- **Subtitle:** "Passphrase-protected file for new device"
- **Handler:** `_exportEncryptedVault()`

The flow:
1. Prompt for passphrase (8+ chars, confirm-twice)
2. Call `exportEncryptedVault(handle, athleteId, passphrase)`
3. Write bytes to temp file with `.mvbackup` extension
4. Open system share sheet via `Share.shareXFiles`

### 3. Erase Confirmation Copy

Updated both dialogs to state no backup survives:

First dialog:
> "This cannot be undone. Your data is not in phone backups, so no copy survives."

Second dialog:
> "This is permanent. Your data will be crypto-erased immediately. No backup
> copy survives — deletion is final."

### 4. CSV Export (updated)

Also wired `share_plus` for CSV export (was placeholder dialog).

## Blocked Items

| Item | Reason |
|------|--------|
| Import on onboarding | `importEncryptedVault` FFI seam not wired through shim |
| Empty-after-restore detection | Needs heuristic to detect platform-restore scenario |

## Files Modified

| File | Changes |
|------|---------|
| `lib/screens/you_screen.dart` | +imports, sovereignty card copy, encrypted export, erase copy |

## Verification

```
flutter analyze  → No issues found!
flutter test     → 269 tests passed
```

## DoD Checklist

- [x] Expectation-setting copy (promise banner)
- [x] "Take your data with you" export action
- [x] Passphrase prompt (8+ chars, confirm)
- [x] Share sheet for encrypted backup
- [x] Erase confirmation mentions no backup
- [ ] Import on onboarding (blocked: FFI seam)
- [ ] Empty-after-restore copy (blocked: detection heuristic)

---

*Updated: 2026-07-06*
