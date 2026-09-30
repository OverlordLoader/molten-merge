import SwiftUI
import SpriteKit

// MARK: - Blob tiers

/// One of the six merge tiers. Two identical blobs that touch merge into the
/// next tier. Tier sizes (and therefore mass) grow roughly quadratically, so
/// big blobs settle while small ones roll into gaps.
enum BlobTier: Int, CaseIterable, Identifiable {
    case spark = 0   // ember orange
    case droplet     // ocean blue
    case orb         // violet
    case bloom       // forest green
    case star        // rose/gold
    case prism       // radiant white-rainbow (max tier)

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .spark: return "Spark"
        case .droplet: return "Droplet"
        case .orb: return "Orb"
        case .bloom: return "Bloom"
        case .star: return "Star"
        case .prism: return "Prism"
        }
    }

    /// Visual radius in points.
    var radius: CGFloat {
        switch self {
        case .spark: return 20
        case .droplet: return 27
        case .orb: return 35
        case .bloom: return 44
        case .star: return 54
        case .prism: return 65
        }
    }

    /// Points awarded for creating this tier via a merge, before the combo
    /// multiplier is applied.
    var scoreValue: Int {
        switch self {
        case .spark: return 10
        case .droplet: return 30
        case .orb: return 80
        case .bloom: return 200
        case .star: return 500
        case .prism: return 1500
        }
    }

    /// The tiers the dropper can hand out. Prism (and usually Star) are only
    /// reachable by merging — that is the whole game.
    static func randomDropTier() -> BlobTier {
        let roll = Double.random(in: 0..<1)
        switch roll {
        case ..<0.36: return .spark
        case ..<0.64: return .droplet
        case ..<0.84: return .orb
        default: return .bloom
        }
    }
}

// MARK: - Blob themes (skins)

/// Purchasable blob skins. Classic is always available; Sakura and Nebula are
/// non-consumable IAPs (see StoreManager). Themes are purely cosmetic — they
/// never change physics, scoring, or drop odds.
enum BlobTheme: String, CaseIterable, Identifiable {
    case classic, sakura, nebula

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .sakura: return "Sakura"
        case .nebula: return "Nebula"
        }
    }

    var tagline: String {
        switch self {
        case .classic: return "The original molten glow"
        case .sakura: return "Cherry-blossom glass with drifting petals"
        case .nebula: return "Cosmic glass with a starfield core"
        }
    }

    /// App Store Connect product ID, or nil for the always-available Classic.
    /// MUST match the products created in App Store Connect exactly.
    var productID: String? {
        switch self {
        case .classic: return nil
        case .sakura: return StoreManager.sakuraThemeID
        case .nebula: return StoreManager.nebulaThemeID
        }
    }

    /// Shown while the App Store product hasn't loaded yet.
    var fallbackPrice: String { "$1.99" }

    // Base colors as 0...1 RGB triples, indexed by tier raw value.
    private var rgbTable: [(CGFloat, CGFloat, CGFloat)] {
        switch self {
        case .classic:
            return [
                (1.00, 0.45, 0.12), // Spark — ember orange
                (0.15, 0.55, 0.95), // Droplet — ocean blue
                (0.55, 0.30, 0.95), // Orb — violet
                (0.20, 0.70, 0.35), // Bloom — forest green
                (0.98, 0.38, 0.55), // Star — rose
                (0.96, 0.97, 1.00), // Prism — radiant white
            ]
        case .sakura:
            return [
                (1.00, 0.55, 0.62),
                (1.00, 0.65, 0.72),
                (0.98, 0.48, 0.66),
                (1.00, 0.75, 0.82),
                (0.96, 0.38, 0.58),
                (1.00, 0.93, 0.96),
            ]
        case .nebula:
            return [
                (0.35, 0.45, 1.00),
                (0.45, 0.32, 0.98),
                (0.58, 0.28, 0.95),
                (0.30, 0.62, 1.00),
                (0.72, 0.38, 1.00),
                (0.88, 0.92, 1.00),
            ]
        }
    }

    func uiColor(for tier: BlobTier) -> UIColor {
        let (r, g, b) = rgbTable[tier.rawValue]
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// SKColor is a typealias of UIColor on iOS, so this converts implicitly.
    func skColor(for tier: BlobTier) -> SKColor { uiColor(for: tier) }

    func swiftUIColor(for tier: BlobTier) -> Color { Color(uiColor(for: tier)) }
}

// MARK: - Game tuning & persistence keys

enum MergeGame {
    /// Minimum seconds between drops.
    static let dropCooldown: TimeInterval = 0.5
    /// How long the pile may rest above the danger line before game over.
    static let dangerHoldTime: TimeInterval = 2.0
    /// Merges closer together than this extend the combo.
    static let comboWindow: TimeInterval = 0.9
    /// Flat bonus when two Prisms annihilate (there is no tier 7).
    static let supernovaBonus = 2500

    static let bestScoreKey = "moltenmerge.bestScore"
    static let hapticsEnabledKey = "moltenmerge.hapticsEnabled"
    static let soundEnabledKey = "moltenmerge.soundEnabled"
}
