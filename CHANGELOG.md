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
