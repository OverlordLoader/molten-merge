# Molten Merge

A Suika-style physics merge puzzler in the Molten universe. Tap to drop glowing
glass blobs into the jar — two identical blobs that touch merge into the next
tier, all the way up to the radiant **Prism**. Game over when the pile rests
above the dashed danger line for ~2 seconds.

- Native SwiftUI + SpriteKit, iOS 17+, portrait only, iPhone
- Bundle ID: `app.moltenmerge.game`
- Offline-capable, no sign-in, no analytics/tracking SDKs beyond AdMob
- All purchases via StoreKit 2 (no external billing or web links)

## How to play

1. Tap anywhere to drop the glowing blob at that position (it falls into the jar).
2. Two identical blobs that touch **merge** into the next tier with a burst:
   Spark → Droplet → Orb → Bloom → Star → **Prism**.
3. Merging two Prisms triggers a **SUPERNOVA** (+2500) — there is no tier 7.
4. Chain merges quickly for **combo multipliers** ("MERGE x3").
5. The run ends when the pile stays above the dashed red line for ~2 seconds.
6. On game over you can **Continue** once per run (watch a rewarded ad — clears
   the top 3 rows) or **Play Again**.

## Project layout

```
MoltenMerge/                  # App target sources
  MoltenMergeApp.swift         # @main: wires StoreManager + AdsManager
  ContentView.swift            # Root view
  Info.plist                   # Display name, portrait, AdMob app ID
  PrivacyInfo.xcprivacy        # Device ID for third-party advertising (tracking=false)
  Assets.xcassets/             # AppIcon set + AccentColor + LaunchBackground
  Game/
    MergeModels.swift          # BlobTier (6 tiers), BlobTheme (3 skins), tuning
    MergeScene.swift           # SpriteKit physics: jar, drops, merges, danger line
    GlassRenderer.swift        # Procedural art: studio bg, glowing blobs, bursts
    Palette.swift              # Candy UI accent palette
    SoundManager.swift         # Synthesized SFX (no audio assets, offline-safe)
    Haptics.swift              # Haptic accents (user-toggleable)
    StoreManager.swift         # StoreKit 2: Remove Ads + 2 themes
    AdsManager.swift           # AdMob: rewarded Continue + interstitial
  Views/
    GameView.swift             # GameViewModel + HUD + SpriteKit host + blob previews
    GameOverView.swift         # Game-over overlay
    SettingsView.swift         # Premium shop, restore, preferences
MoltenMerge.xcodeproj/         # Generated — do not hand-edit
tools/gen_pbxproj.py           # Regenerates the .xcodeproj (deterministic)
scripts/
  generate_icons.py            # Regenerates the AppIcon set (PIL)
  apple-release.py             # Signs + validates a release on the macOS runner
  apple-release-check.py       # Pre-release safety checks (runs on ubuntu)
```

Regenerate the Xcode project after adding/removing source files:

```
python3 tools/gen_pbxproj.py
```

## Monetization setup

Monetization is built in from day one. The full game is free; revenue comes
from **Remove Ads** and two cosmetic **theme packs** (never pay-to-win).

### 1. App Store Connect — in-app purchases

Create these exact products under the `app.moltenmerge.game` app record:

| Product ID | Type | Price | Name |
|---|---|---|---|
| `app.moltenmerge.game.removeads` | Non-consumable | $4.99 | Remove Ads |
| `app.moltenmerge.game.theme.sakura` | Non-consumable | $1.99 | Sakura Theme |
| `app.moltenmerge.game.theme.nebula` | Non-consumable | $1.99 | Nebula Theme |

Product IDs must match **character-for-character** — the app looks them up by
these strings (`StoreManager`). Banking/tax agreements must be complete in
App Store Connect before IAPs can be sold.

### 2. AdMob

1. Create an AdMob account at apps.admob.com, add an **iOS app** for Molten Merge.
2. Create two ad units: one **Rewarded**, one **Interstitial**.
3. In `MoltenMerge/Game/AdsManager.swift`, replace the two
   `// TODO(Henry): replace with real AdMob IDs` constants with your unit IDs.
4. In `MoltenMerge/Info.plist`, replace the `GADApplicationIdentifier` test ID
   with your real AdMob **app ID**.

Debug builds use Google's official test IDs automatically (`#if DEBUG`).

### Ad behavior (by design)

- **Rewarded** — "Continue" on the game-over screen, once per run. Watching it
  clears the top 3 rows of blobs and resumes the run.
- **Interstitial** — after a game over only (shown when dismissing the game-over
  overlay), at most every 3rd game-over, never during the first 3 game-overs.
- **Remove Ads** owners never see any ad, immediately after purchase.
- Ads fail gracefully offline: gameplay is never blocked; loads retry silently.

### Privacy labels

`PrivacyInfo.xcprivacy` declares **Device ID** collected for **Third-Party
Advertising**, not linked to the user, tracking = false (no IDFA, no
AppTrackingTransparency). Mirror this in the App Store Connect privacy
nutrition label.

## Release process

1. Henry uploads `~/workspace/your_files/moltenmerge-apple-release.yml` to the
   repo as `.github/workflows/apple-release.yml` via the GitHub web UI
   (the app token cannot push workflow files).
2. Create the `app-store-release-moltenmerge` environment in the repo settings
   with secrets: `APPLE_DISTRIBUTION_P12_BASE64`,
   `APPLE_DISTRIBUTION_P12_PASSWORD`, `APPLE_PROFILE_BASE64`
   (App Store provisioning profile for `app.moltenmerge.game`),
   `APP_STORE_CONNECT_KEY_BASE64`.
3. Run `python3 scripts/apple-release-check.py` locally (also runs in CI).
4. Trigger **workflow_dispatch** on `main` with a unique build number; set
   `upload: true` to push the validated .ipa to App Store Connect
   (validation always runs; submission for review is a manual step in
   App Store Connect).

## Review-safety notes

- Portrait only (`UISupportedInterfaceOrientations`), iOS 17+ floor.
- `ITSAppUsesNonExemptEncryption = false` (no custom crypto).
- No `http://` URLs, no external `open()` calls, no web links anywhere.
- No analytics/tracking SDK imports — the release check bans Firebase,
  AppTrackingTransparency, AdSupport, Facebook, Amplitude, Mixpanel
  (GoogleMobileAds is allow-listed as the ad network).
- First compile is unverified on this Linux VM — the first macOS pipeline run
  (or local Xcode build) is the compile gate.
