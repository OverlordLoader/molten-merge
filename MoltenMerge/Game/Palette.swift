import SwiftUI
import SpriteKit

// MARK: - Color helpers

extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    func darkened(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - amount, 0), green: max(g - amount, 0),
                       blue: max(b - amount, 0), alpha: a)
    }

    func lightened(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r + amount, 1), green: min(g + amount, 1),
                       blue: min(b + amount, 1), alpha: a)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0)
    }
}

// MARK: - UI accent palette

/// Candy-bright accents for HUD text, buttons, and popups. The blobs
/// themselves get their colors from BlobTheme, not from here.
struct AccentColor: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let hex: UInt32

    var swiftUIColor: Color { Color(hex: hex) }
    var skColor: SKColor { SKColor(hex: hex) }
    var darkSK: SKColor { SKColor(hex: hex).darkened(0.30) }
    var lightSK: SKColor { SKColor(hex: hex).lightened(0.38) }
}

enum Palette {
    static let all: [AccentColor] = [
        AccentColor(id: 0, name: "Cherry", hex: 0xFF3B5C),
        AccentColor(id: 1, name: "Tangerine", hex: 0xFF8A00),
        AccentColor(id: 2, name: "Lemon", hex: 0xFFD60A),
        AccentColor(id: 3, name: "Lime", hex: 0x7ED957),
        AccentColor(id: 4, name: "Mint", hex: 0x00C2A8),
        AccentColor(id: 5, name: "Sky", hex: 0x3AB6FF),
        AccentColor(id: 6, name: "Blueberry", hex: 0x5B5FE9),
        AccentColor(id: 7, name: "Grape", hex: 0xA259FF),
        AccentColor(id: 8, name: "Bubblegum", hex: 0xFF5FD2),
        AccentColor(id: 9, name: "Lagoon", hex: 0x00B4D8),
    ]

    static func color(id: Int) -> AccentColor {
        all[id % all.count]
    }

    /// Signature accents used across the HUD.
    static let score = all[5]    // Sky
    static let best = all[2]     // Lemon
    static let danger = all[0]   // Cherry
    static let premium = all[7]  // Grape
}
