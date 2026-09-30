## 2026-09-30 � Repair SpriteKit delegate name collision

Actual native compilation found MergeScene.delegate conflicting with inherited SKScene.delegate. Renamed only the game callback property and all its callers to gameDelegate; physics contact delegation and gameplay rules remain intact. Corrective native verification follows.

## 2026-09-30 — Unsigned native simulator verification

Added a free public macOS compile/startup workflow, evidence capture, and a shared Xcode scheme where missing. Supports opening the existing game on Henry's MacBook without App Store submission. No paid service, signing or purchase. Build status is reported separately from full gameplay acceptance.

# Changelog

All notable changes to Molten Merge. The format follows Keep a Changelog;
entries are added per change. The VISION.md changelog mirrors these.

## [Unreleased]

### Added
- Initial game: Suika-style physics merge puzzler (SwiftUI + SpriteKit, iOS 17+, portrait).
  - 6 merge tiers (Spark → Droplet → Orb → Bloom → Star → Prism), Prism+Prism supernova bonus.
  - Tap-to-drop with cooldown, next-piece preview, score + persisted best score.
  - Danger-line game over (~2s hold), combo multipliers with popup text.
  - Juice: merge particle bursts, screen shake-lite on big merges, haptics,
    synthesized SFX (drop/merge pitch-rises-with-tier/combo/game-over/resume).
  - Procedural molten-glass art: studio backdrop with furnace glow, glowing
    blobs with rim light + halo + specular, frosted-glass jar.
- Monetization built in from day one:
  - Google Mobile Ads via SPM (pinned 11.x): rewarded "Continue" (clears top 3
    rows, once per run), interstitial after game over (every 3rd, first 3 exempt).
  - StoreKit 2 StoreManager: Remove Ads $4.99 + Sakura/Nebula themes $1.99 each
    (non-consumables), transaction verification + finish, updates listener,
    AppStore.sync() restore, refund revocation.
  - Settings screen: live-price Remove Ads row, theme shop with skin previews,
    Restore Purchases, sound/haptics toggles, error alerts. No dead buttons.
  - PrivacyInfo.xcprivacy: Device ID for third-party advertising (tracking=false).
  - Generated AppIcon set (9 PNGs) via scripts/generate_icons.py.
- Release pipeline: deterministic pbxproj generator (tools/gen_pbxproj.py),
  apple-release.py signer, apple-release-check.py safety checks, and the
  out-of-repo workflow (~/workspace/your_files/moltenmerge-apple-release.yml)
  using the dedicated `app-store-release-moltenmerge` environment.

### Fixed
- AdsManager written against the verified GMA 11.x API surface
  (`present(fromRootViewController:...)`); the 11.x pin is enforced by the
  release check. (GMA 12.x renamed Swift labels and 13.x removed the GAD
  prefix — do not bump major without rewriting AdsManager.)


## September 30, 2026 - Independent source verification

Declared the app-scoped UserDefaults required-reason API (CA92.1), based on the app's actual preferences and local save calls. This does not certify App Store privacy answers or third-party SDK behavior. Final signed archive privacy reports and actual-device/network behavior remain release gates.

Versioned the previously missing release workflow with pinned actions, app-specific identity/environment, manual main-branch signing and upload disabled by default. Removed the incorrect requirement that workflows must stay outside GitHub. Signing environments/secrets, account budget and actual Mac builds remain unverified; nothing dispatched.
