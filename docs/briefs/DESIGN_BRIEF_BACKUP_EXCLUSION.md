# Design Brief — Platform-backup exclusion: what it means for the UX

**From:** engine seat (branch `claude/mivalta-plan-model-eval-rtbsuq`)
**To:** design seat
**Date:** 2026-07-06
**Companion code:** `ios/Runner/AppDelegate.swift` (`excludeAppDataFromBackup`),
`android/.../data_extraction_rules.xml` + manifest attribute
**Canonical decision:** mivalta-rust-engine `docs/DECISIONS.md` Entry AM,
invariant I-7 — *platform backups are vault-free*

---

## What changed (invisible in the UI, load-bearing for the promise)

The app's data directory — the encrypted vault (`vault.db`), its key files
(`vault.key`, `cache.key`), and the ledger — is now **excluded from iCloud /
Finder backups on iOS and from Google cloud backup + device-to-device
transfer on Android**.

Why this is non-negotiable, in one paragraph: the vault's encryption key
lives on the device beside the ciphertext it protects. A platform backup
would carry **keys and ciphertext together**, so anyone holding the backup
holds the data — the encryption would buy nothing. It would also break the
crypto-erasure promise ("delete my data" destroys the key, making the vault
unrecoverable): a destroyed key survives inside every old backup. Excluding
the directory is what makes both promises true.

## The UX consequence design must own

**Health and training data does NOT come back with a phone restore.** When a
user restores a new phone from iCloud/Google backup, MiValta reinstalls but
starts EMPTY. This is correct behavior, not a bug — but to a user it looks
like data loss unless we set the expectation.

**The sanctioned migration path is the V5 encrypted vault export/import**
(passphrase-keyed, user-initiated, already in the engine: VaultEngine
export/import methods). Platform backup is never the migration path.

## Design decisions this opens

1. **"Moving to a new phone" flow.** Settings needs a clearly findable
   export action ("Take your data with you") framed as the way to move
   devices — passphrase-protected file the user stores wherever they choose.
   And onboarding needs the import counterpart ("Restoring from an export?").
2. **Expectation-setting copy.** Somewhere honest and calm — likely the
   You/Settings privacy surface — the fact in plain words: "Your health data
   never leaves this device, and it is never in your phone backups. To move
   it to a new phone, use the encrypted export." This is a sovereignty
   FEATURE; the copy should carry it as one, not as a caveat.
3. **Deletion promise copy can now be stated fully.** "Delete my data"
   (crypto-erasure) is genuinely final — no backup copy survives. Design may
   state this plainly in the deletion confirmation; before this change that
   sentence would have been false on iOS.
4. **Empty-after-restore moment (edge, worth a decision).** A user who
   restored from a platform backup and opens MiValta sees a fresh app. Do we
   add a line to the fresh-start onboarding acknowledging it ("Restored your
   phone? Your MiValta data stays out of phone backups by design — import
   your encrypted export, or start fresh.")? Recommended, one sentence.

## Locked constraints

- No paraphrasing the promise into something softer or grander than the
  mechanism: excluded from platform backups; migrated only via encrypted
  export; deletion is final. Every claim above traces to shipped code.
- F1 no-data copy and all other locked copy remain untouched.
