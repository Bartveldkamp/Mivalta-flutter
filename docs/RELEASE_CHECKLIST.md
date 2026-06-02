# MiValta Release Checklist

PR-I: Release hardening checklist for Play Store submission.

## Prerequisites

Before your first release build, complete these one-time setup steps.

---

## 1. Create Upload Keystore (One-Time)

Google Play requires all APKs/AABs to be signed. Create a release keystore:

```bash
# Generate a new keystore (run once, keep forever)
keytool -genkey -v \
  -keystore ~/mivalta-upload-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# You'll be prompted for:
# - Keystore password (save this!)
# - Key password (can be same as keystore password)
# - Your name, organization, etc.
```

**CRITICAL**: Back up `mivalta-upload-key.jks` and passwords securely (password manager, encrypted backup). If lost, you cannot update the app on Play Store.

---

## 2. Create key.properties (Per-Machine)

Create `android/key.properties` with your keystore details:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/mivalta-upload-key.jks
```

**NEVER commit this file** — it's already in `.gitignore`.

---

## 3. Build Release Bundle

```bash
# Clean build
flutter clean
flutter pub get

# Generate icons and splash (if assets changed)
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# Build release AAB for Play Store
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 4. Pre-Release Gates

Run all checks before uploading to Play Store:

```bash
# Static analysis
flutter analyze

# Unit tests
flutter test

# Rust engine tests (from mivalta-rust-engine/)
cargo test --workspace

# Verify AAB builds without error
flutter build appbundle --release
```

All must pass with zero errors.

---

## 5. Play Console App Creation

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app:
   - App name: **MiValta**
   - Default language: English (United States)
   - App or game: **App**
   - Free or paid: **Free**
3. Complete store listing:
   - Short description (80 chars): "Privacy-first AI fitness coach. 100% on-device."
   - Full description (4000 chars): [See below]
   - Screenshots: Phone, 7" tablet, 10" tablet
   - Feature graphic: 1024x500
   - App icon: 512x512
4. Complete content rating questionnaire
5. Set up pricing and distribution
6. Complete Data safety form (see below)

---

## 6. Data Safety Form — Draft Answers

Google Play requires a Data safety declaration. MiValta's privacy-first architecture makes this straightforward.

### Data Collection Summary

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Health & fitness | Yes | No | Core functionality |
| Personal info | Yes | No | Profile (name, age, sport) |
| Device IDs | No | No | — |
| Location | No | No | — |
| Financial info | No | No | — |
| Contacts | No | No | — |
| Photos/videos | No | No | — |
| Audio | No | No | — |

### Detailed Answers

**Does your app collect or share any of the required user data types?**
- Yes, collects: Health & fitness data, Personal info

**Is all of the user data collected by your app encrypted in transit?**
- N/A — No user data is transmitted. All data stays on-device.

**Do you provide a way for users to request that their data be deleted?**
- Yes — Users can delete all data via in-app "Erase All Data" function (crypto-shreds the vault).

### Health & Fitness Data

**What health & fitness data is collected?**
- Heart rate (from Health Connect/HealthKit)
- Heart rate variability
- Sleep data
- Oxygen saturation
- Step count
- Workout/exercise data (manual entry)

**Is this data collected, shared, or both?**
- Collected only. Never shared.

**Is this data processed ephemerally?**
- No, data is stored on-device in an encrypted vault (SQLCipher AES-256-GCM).

**Is this data required for your app, or can users choose whether it's collected?**
- Optional — app functions with manual data entry if health permissions denied.

**Why is this data collected?**
- App functionality: Calculate readiness scores, generate training recommendations.

### Personal Info

**What personal info is collected?**
- Name (optional, for personalization)
- Age/birth year (for physiological calculations)

**Why is this data collected?**
- App functionality: Age affects zone calculations and recovery modeling.

### Security Practices

**Is your app compliant with the Families Policy?**
- N/A — App is not designed for children.

**Does your app follow Google's User Data policy?**
- Yes.

**Does your app provide privacy & security practices?**
- Yes:
  - All data encrypted at rest (SQLCipher AES-256-GCM)
  - No network transmission of user data
  - Crypto-shred deletion available
  - No third-party analytics
  - No advertising SDKs

### Data Deletion

**Can users request data deletion?**
- Yes — "Erase All Data" in settings crypto-shreds all user data.

**Where can users request deletion?**
- In-app: Settings → Privacy → Erase All Data

---

## 7. Privacy Policy

A privacy policy URL is required for Play Store. Host at:
- `https://mivalta.com/privacy` (when domain is live)
- Or GitHub Pages: `https://bartveldkamp.github.io/mivalta-privacy`

### Privacy Policy — Key Points

1. **Data stays on-device**: MiValta never transmits user health or personal data to any server.
2. **No cloud sync**: All data stored locally in encrypted vault.
3. **No analytics**: No Firebase, no Amplitude, no tracking.
4. **No ads**: No advertising SDKs.
5. **Health data**: Read from Health Connect (Android) / HealthKit (iOS) with explicit user permission. Used only for readiness calculations.
6. **Network usage**: One-time model download only. No ongoing connectivity required.
7. **Data deletion**: Users can crypto-shred all data via in-app function.

---

## 8. Version Bumping

For each release, update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1  # versionName+versionCode
```

- `versionName` (1.0.0): User-visible version
- `versionCode` (1): Must increment for each Play Store upload

Play Store rejects uploads if versionCode doesn't increase.

---

## 9. Upload to Play Console

1. Go to Release → Production (or Internal testing first)
2. Create new release
3. Upload `app-release.aab`
4. Add release notes
5. Review and roll out

---

## 10. Post-Release

- [ ] Monitor crash reports in Play Console
- [ ] Respond to user reviews
- [ ] Monitor ANR (Application Not Responding) rates
- [ ] Check vitals for startup time, battery usage

---

## Troubleshooting

### "Keystore was tampered with, or password was incorrect"
- Double-check password in key.properties
- Ensure storeFile path is absolute and correct

### "No key with alias 'upload' found in keystore"
- Verify keyAlias in key.properties matches what you used in keytool -alias

### Release build crashes but debug works
- Check ProGuard rules in android/app/proguard-rules.pro
- Native bindings may be stripped — add keep rules

### Health Connect permissions not appearing
- Verify health_permissions array in res/values/health_permissions.xml
- Check intent-filter in AndroidManifest.xml

---

## File Checklist

Before release, verify these files exist and are configured:

- [ ] `android/key.properties` (not committed, local only)
- [ ] `android/app/proguard-rules.pro` (keep rules for JNI)
- [ ] `android/app/src/main/res/xml/network_security_config.xml`
- [ ] `android/app/src/main/res/values/health_permissions.xml`
- [ ] `assets/compiled_tables.json` (knowledge tables)
- [ ] App icon assets (when brand art ready)
- [ ] Splash screen assets (when brand art ready)
