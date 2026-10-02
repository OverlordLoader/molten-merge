# VISION.md — Molten Merge

## Vision

**Molten Merge** is the arcade corner of the Molten universe: a cozy, juicy
Suika-style physics merge puzzler. Tap to drop glowing glass blobs into the
furnace jar; identical blobs fuse into the next tier, climbing from humble
**Spark** to the radiant **Prism**. One more merge past Prism and the jar goes
supernova.

It should feel like playing with molten glass — warm, tactile, satisfying —
in 30-second bursts or 20-minute "one more run" sessions. The free game is the
whole game; money comes from players who love it enough to remove ads or dress
their blobs up, never from withholding gameplay.

## Philosophy

- **Free tier must be genuinely usable — help players first, then convert.**
  Every tier, every merge, combos, Continue-via-ad, and the full endless run
  are free forever. Monetization is Remove Ads ($4.99) and two cosmetic theme
  packs ($1.99 each). Nothing gameplay-affecting is ever sold.
- **No dark patterns.** No timers, no energy, no pay-to-win, no loot boxes.
  The rewarded ad is an explicit, opt-in Continue (once per run). The
  interstitial only appears after a game over, at most every 3rd one, never in
  the first 3.
- **Offline-first.** The game runs fully offline; ads fail gracefully and never
  block gameplay. No sign-in, no accounts.
- **Zero data collection beyond ads.** No analytics/tracking SDKs. The privacy
  manifest declares Device ID for third-party advertising only (tracking=false,
  no IDFA). Everything else stays on-device (best score, settings, entitlements).

## Pricing

| Product | Type | Price | Product ID |
|---|---|---|---|
| Remove Ads | Non-consumable | $4.99 | `app.moltenmerge.game.removeads` |
| Sakura Theme (cherry-blossom skins) | Non-consumable | $1.99 | `app.moltenmerge.game.theme.sakura` |
| Nebula Theme (cosmic skins) | Non-consumable | $1.99 | `app.moltenmerge.game.theme.nebula` |

All purchases are StoreKit 2 only — no external billing, no web links.

## Current state (2026-09-29)

- **Milestone 1 (gameplay) + monetization: built, not yet compiled.** 13 Swift
  sources, full game loop (drop → merge → combo → danger-line game over →
  Continue/Play Again), procedural molten-glass art, synthesized SFX, haptics,
  best-score persistence.
- Monetization wired end-to-end in code: AdMob (SPM, pinned 11.x — the API
  surface AdsManager was verified against via the 11.10.0 headers), StoreKit 2
  with the three product IDs above, Settings shop, privacy manifest, generated
  AppIcon set.
- Release pipeline ready: deterministic pbxproj generator, signing script,
  safety checks (all passing locally), out-of-repo workflow YAML awaiting
  Henry's upload.
- **Not yet done:** first compile (needs the macOS pipeline or Xcode — no Swift
  toolchain on this VM); App Store Connect IAP products; AdMob account + ad
  units + real IDs; provisioning profile for `app.moltenmerge.game`;
  `app-store-release-moltenmerge` environment secrets; banking/tax forms;
  TestFlight playtest; app preview video + submission (Henry).

## Conventions (for Henry and every AI tool working in this repo)

- **Review branches only — never merge to the default branch (`main`) without
  Henry.** Propose changes as branches/PRs; Henry merges.
- **No secrets in code.** AdMob IDs live behind `TODO(Henry)` markers; signing
  material only ever exists as GitHub environment secrets.
- **One purchase flow per platform.** iOS = StoreKit 2, always. No external
  billing links, no alternative payment paths.
- **Keep the GMA 11.x pin.** GMA 12.x renamed Swift API labels and 13.x removed
  the `GAD` prefix; `AdsManager.swift` is written against 11.x. The release
  check enforces the pin — bumping major requires rewriting AdsManager.
- **Regenerate, don't hand-edit**, `MoltenMerge.xcodeproj/project.pbxproj`
  (via `tools/gen_pbxproj.py`) and the AppIcon set (via
  `scripts/generate_icons.py`).
- **Update this file's changelog with every change**, and mirror entries in
  CHANGELOG.md.

## Changelog

- 2026-09-29: Repo created. Initial game + day-one monetization built
  (gameplay, art, SFX/haptics, AdMob, StoreKit 2 shop, privacy manifest,
  icons, release pipeline). Awaiting first compile on the macOS pipeline and
  Henry's App Store Connect / AdMob setup.


## September 30, 2026 - Independent source verification

Declared the app-scoped UserDefaults required-reason API (CA92.1), based on the app's actual preferences and local save calls. This does not certify App Store privacy answers or third-party SDK behavior. Final signed archive privacy reports and actual-device/network behavior remain release gates.

Versioned the previously missing release workflow with pinned actions, app-specific identity/environment, manual main-branch signing and upload disabled by default. Removed the incorrect requirement that workflows must stay outside GitHub. Signing environments/secrets, account budget and actual Mac builds remain unverified; nothing dispatched.
