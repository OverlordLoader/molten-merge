import SpriteKit
import UIKit

/// Procedural visual core for Molten Merge, adapted from Molten's
/// GlassRenderer: studio backdrop, glowing glass blobs with rim light and
/// halo, merge bursts, combo popups, and the glass jar.
/// Everything is generated in code via UIGraphicsImageRenderer -> SKTexture.
enum GlassRenderer {

    // MARK: - Texture helpers

    /// Cached soft round particle dot (white core fading to transparent).
    private static let softDotTexture: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(white: 1, alpha: 1).cgColor,
                UIColor(white: 1, alpha: 0.4).cgColor,
                UIColor(white: 1, alpha: 0).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: [0, 0.4, 1])!
            c.drawRadialGradient(gradient,
                                 startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                 endCenter: CGPoint(x: 16, y: 16), endRadius: 16,
                                 options: [])
        }
        return SKTexture(image: image)
    }()

    private static func radialTexture(size: CGSize,
                                      stops: [(CGFloat, UIColor)],
                                      radius: CGFloat? = nil) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = radius ?? max(size.width, size.height) * 0.5
            let colors = stops.map { $0.1.cgColor } as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: stops.map { $0.0 })!
            c.drawRadialGradient(gradient,
                                 startCenter: center, startRadius: 0,
                                 endCenter: center, endRadius: r,
                                 options: [])
        }
        return SKTexture(image: image)
    }

    /// Cached cherry-blossom petal used by the Sakura theme.
    private static let petalTexture: SKTexture = {
        let size = CGSize(width: 24, height: 24)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(red: 1, green: 0.85, blue: 0.9, alpha: 1).cgColor,
                UIColor(red: 1, green: 0.6, blue: 0.72, alpha: 0.9).cgColor,
                UIColor(red: 1, green: 0.6, blue: 0.72, alpha: 0).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: [0, 0.55, 1])!
            c.drawRadialGradient(gradient,
                                 startCenter: CGPoint(x: 12, y: 12), startRadius: 0,
                                 endCenter: CGPoint(x: 12, y: 12), endRadius: 12,
                                 options: [])
        }
        return SKTexture(image: image)
    }()

    // MARK: - Studio background

    /// Dark studio backdrop. Children are laid out around the node's center
    /// (caller positions the returned node, e.g. at the scene center).
    static func studioBackground(size: CGSize) -> SKNode {
        let root = SKNode()

        // 1. Full-screen vertical gradient: deep blue-black top -> warm dark brown bottom.
        let bgImage = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let top = UIColor(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x14 / 255.0, alpha: 1)
            let bottom = UIColor(red: 0x1A / 255.0, green: 0x0F / 255.0, blue: 0x08 / 255.0, alpha: 1)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [top.cgColor, bottom.cgColor] as CFArray,
                                      locations: [0, 1])!
            // Image space is y-down: y = 0 is the top of the screen.
            c.drawLinearGradient(gradient,
                                 start: CGPoint(x: size.width / 2, y: 0),
                                 end: CGPoint(x: size.width / 2, y: size.height),
                                 options: [])
        }
        let bg = SKSpriteNode(texture: SKTexture(image: bgImage), size: size)
        bg.zPosition = -10
        root.addChild(bg)

        // 2. Warm furnace glow near bottom-center.
        let glow = SKSpriteNode(texture: radialTexture(
            size: CGSize(width: size.width * 1.1, height: size.height * 0.55),
            stops: [
                (0.0, UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 0.55)),
                (0.5, UIColor(red: 0.9, green: 0.30, blue: 0.08, alpha: 0.18)),
                (1.0, UIColor(red: 0.9, green: 0.30, blue: 0.08, alpha: 0.0)),
            ]))
        glow.position = CGPoint(x: 0, y: -size.height * 0.32)
        glow.blendMode = .add
        glow.zPosition = -9
        root.addChild(glow)

        // 3. Vignette: darkened edges. Radius uses the full diagonal so corners are covered.
        let vignette = SKSpriteNode(texture: radialTexture(
            size: size,
            stops: [
                (0.0, UIColor(white: 0, alpha: 0.0)),
                (0.55, UIColor(white: 0, alpha: 0.0)),
                (1.0, UIColor(white: 0, alpha: 0.7)),
            ],
            radius: hypot(size.width, size.height) / 2))
        vignette.zPosition = 10
        root.addChild(vignette)

        // 4. Two ambient ember emitters low on screen.
        for x in [-size.width * 0.28, size.width * 0.28] {
            let emitter = emberEmitter()
            emitter.position = CGPoint(x: x, y: -size.height * 0.38)
            emitter.zPosition = -8
            root.addChild(emitter)
        }

        return root
    }

    // MARK: - Merge blob

    /// A glowing glass blob: white-hot core, theme-colored body, baked-in
    /// rim-light crescent, specular dot, additive glow layers with a gentle
    /// heat-shimmer, plus per-theme dressing (sakura petals, nebula
    /// starfield, prism heat sparks).
    static func mergeBlobNode(radius: CGFloat, tier: BlobTier, theme: BlobTheme) -> SKNode {
        let root = SKNode()
        let base: UIColor = theme.uiColor(for: tier)
        let d = radius * 2
        let box = CGSize(width: d, height: d)

        // Core sprite: white-hot center -> theme color -> transparent edge,
        // with a rim-light crescent on the upper-left and (for Nebula) a
        // baked-in starfield.
        let coreTexture: SKTexture = {
            let image = UIGraphicsImageRenderer(size: box).image { ctx in
                let c = ctx.cgContext
                let center = CGPoint(x: d / 2, y: d / 2)
                let colors = [
                    UIColor(white: 1, alpha: 1).cgColor,
                    base.cgColor,
                    base.withAlphaComponent(0.55).cgColor,
                    base.withAlphaComponent(0).cgColor,
                ] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: colors,
                                          locations: [0, 0.28, 0.68, 1])!
                c.drawRadialGradient(gradient,
                                     startCenter: center, startRadius: 0,
                                     endCenter: center, endRadius: radius,
                                     options: [])
                // Rim light: thin white crescent along the upper-left edge.
                // (Angles are in image space, y-down: 0.75pi..1.35pi is upper-left.)
                c.saveGState()
                c.setStrokeColor(UIColor(white: 1, alpha: 0.55).cgColor)
                c.setLineWidth(max(2, radius * 0.09))
                c.setLineCap(.round)
                c.addArc(center: center, radius: radius * 0.80,
                         startAngle: CGFloat.pi * 0.75, endAngle: CGFloat.pi * 1.35,
                         clockwise: false)
                c.strokePath()
                c.restoreGState()
                // Nebula starfield speckles.
                if theme == .nebula {
                    c.setFillColor(UIColor(white: 1, alpha: 0.9).cgColor)
                    let seeds: [(CGFloat, CGFloat, CGFloat)] = [
                        (0.32, 0.40, 0.035), (0.62, 0.30, 0.025), (0.55, 0.62, 0.040),
                        (0.38, 0.68, 0.028), (0.70, 0.55, 0.022), (0.28, 0.58, 0.030),
                    ]
                    for (fx, fy, fr) in seeds {
                        c.fillEllipse(in: CGRect(x: d * fx - d * fr, y: d * fy - d * fr,
                                                 width: d * fr * 2, height: d * fr * 2))
                    }
                }
            }
            return SKTexture(image: image)
        }()

        let core = SKSpriteNode(texture: coreTexture)
        core.zPosition = 2

        let mid = SKSpriteNode(texture: coreTexture)
        mid.setScale(1.7)
        mid.blendMode = .add
        mid.alpha = 0.45
        mid.zPosition = 1

        let halo = SKSpriteNode(texture: coreTexture)
        halo.setScale(2.6)
        halo.blendMode = .add
        halo.alpha = 0.18
        halo.zPosition = 0

        root.addChild(halo)
        root.addChild(mid)
        root.addChild(core)

        // Specular highlight dot, upper-left.
        let spec = SKSpriteNode(texture: softDotTexture)
        spec.setScale((radius * 0.45) / 32.0)
        spec.position = CGPoint(x: -radius * 0.30, y: radius * 0.34)
        spec.blendMode = .add
        spec.alpha = 0.85
        spec.zPosition = 3
        root.addChild(spec)

        // Heat shimmer: glow layers breathe on slightly different periods.
        mid.run(.repeatForever(.sequence([
            SKAction.scale(to: 1.7 * 1.06, duration: 0.45),
            SKAction.scale(to: 1.7, duration: 0.45),
        ])))
        halo.run(.repeatForever(.sequence([
            SKAction.scale(to: 2.6 * 1.06, duration: 0.7),
            SKAction.scale(to: 2.6, duration: 0.7),
        ])))
        mid.run(.repeatForever(.sequence([
            SKAction.fadeAlpha(to: 0.58, duration: 0.55),
            SKAction.fadeAlpha(to: 0.42, duration: 0.55),
        ])))

        // Theme dressing.
        if theme == .sakura {
            let spinner = SKNode()
            for i in 0..<3 {
                let petal = SKSpriteNode(texture: petalTexture)
                let angle = CGFloat(i) * (2 * .pi / 3)
                petal.position = CGPoint(x: cos(angle) * radius * 1.15,
                                         y: sin(angle) * radius * 1.15)
                petal.setScale(0.9)
                petal.zPosition = 1
                spinner.addChild(petal)
            }
            spinner.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 9)))
            root.addChild(spinner)
        }
        if tier == .prism {
            let sparks = emberEmitter()
            sparks.particleColor = SKColor(white: 1, alpha: 1)
            sparks.particleBirthRate = 6
            root.addChild(sparks)
        }

        return root
    }

    // MARK: - Jar, danger line, popups

    /// Frosted-glass jar outline, open at the top. `rect` is in the caller's
    /// coordinate space; the node is positioned so children span the rect.
    static func jarNode(rect: CGRect) -> SKNode {
        let root = SKNode()
        let path = UIBezierPath()
        let bl = CGPoint(x: rect.minX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.minY)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: bl)
        path.addQuadCurve(to: br, controlPoint: CGPoint(x: rect.midX, y: rect.minY - rect.width * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        let glass = SKShapeNode(path: path.cgPath)
        glass.strokeColor = SKColor(white: 1, alpha: 0.28)
        glass.lineWidth = 5
        glass.lineCap = .round
        glass.zPosition = 4
        root.addChild(glass)

        // Faint inner fill for the frosted look.
        let fillPath = UIBezierPath()
        fillPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        fillPath.addLine(to: bl)
        fillPath.addQuadCurve(to: br, controlPoint: CGPoint(x: rect.midX, y: rect.minY - rect.width * 0.08))
        fillPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        fillPath.close()
        let fill = SKShapeNode(path: fillPath.cgPath)
        fill.fillColor = SKColor(white: 1, alpha: 0.045)
        fill.strokeColor = .clear
        fill.zPosition = -1
        root.addChild(fill)

        return root
    }

    /// Dashed red danger line texture, rendered at the exact pixel width so
    /// the dashes never stretch.
    static func dashedLineTexture(width: CGFloat) -> SKTexture {
        let h: CGFloat = 6
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: h)).image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor(UIColor(red: 1, green: 0.35, blue: 0.4, alpha: 0.85).cgColor)
            c.setLineWidth(3)
            c.setLineDash(phase: 0, lengths: [14, 10])
            c.setLineCap(.round)
            c.move(to: CGPoint(x: 0, y: h / 2))
            c.addLine(to: CGPoint(x: width, y: h / 2))
            c.strokePath()
        }
        return SKTexture(image: image)
    }

    /// Floating score/combo text. Rises, pops, fades, and removes itself.
    static func popupLabel(text: String, color: SKColor, fontSize: CGFloat = 30) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold" // falls back to the system font if missing
        label.fontSize = fontSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.zPosition = 20
        label.setScale(0.6)
        label.run(.sequence([
            .group([
                .scale(to: 1.15, duration: 0.16),
                .moveBy(x: 0, y: 26, duration: 0.7),
            ]),
            .group([
                .scale(to: 1.0, duration: 0.12),
                .fadeOut(withDuration: 0.45),
            ]),
            .removeFromParent(),
        ]))
        return label
    }

    // MARK: - Particles

    /// Ambient rising sparks: small soft dots drifting upward.
    static func emberEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softDotTexture
        e.particleBirthRate = 10
        e.particleLifetime = 2.6
        e.particleLifetimeRange = 1.0
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.5
        e.particleSpeed = 65
        e.particleSpeedRange = 25
        e.xAcceleration = 8
        e.particleScale = 0.05
        e.particleScaleSpeed = -0.015
        e.particleColor = SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1.0)
        e.particleColorBlendFactor = 1.0
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -0.3
        e.particleBlendMode = .add
        e.particlePositionRange = CGVector(dx: 50, dy: 8)
        return e
    }

    /// One-shot merge burst. The caller positions the returned node;
    /// it removes itself after firing.
    static func burst(at point: CGPoint, color: SKColor) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.position = point
        e.particleTexture = softDotTexture
        e.numParticlesToEmit = 42
        e.particleBirthRate = 300
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 130
        e.particleSpeedRange = 130
        e.particleLifetime = 0.9
        e.particleScale = 0.1
        e.particleScaleSpeed = -0.09
        e.particleColor = color
        e.particleColorBlendFactor = 1.0
        e.particleAlpha = 1.0
        e.particleAlphaSpeed = -1.0
        e.particleBlendMode = .add
        e.yAcceleration = -120
        // Self-cleanup: all 42 particles are out well before 1.4s.
        e.run(.sequence([
            SKAction.wait(forDuration: 1.4),
            SKAction.removeFromParent(),
        ]))
        return e
    }
}
