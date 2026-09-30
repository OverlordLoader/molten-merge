import SpriteKit
import UIKit

/// Callbacks from the physics scene into SwiftUI (via GameViewModel).
/// SpriteKit always calls these on the main thread.
protocol MergeSceneDelegate: AnyObject {
    func mergeScene(_ scene: MergeScene, didChangeScore score: Int)
    func mergeScene(_ scene: MergeScene, didChangeTiers current: BlobTier, next: BlobTier)
    func mergeSceneDidEnd(_ scene: MergeScene)
}

private enum PhysicsCategory {
    static let blob: UInt32 = 0x1
    static let wall: UInt32 = 0x2
}

/// One physics blob. The visual (glow layers, theme dressing) lives in a
/// child named "visual" so pop animations never touch the physics body.
final class BlobNode: SKNode {
    let tier: BlobTier
    var merging = false

    init(tier: BlobTier, theme: BlobTheme) {
        self.tier = tier
        super.init()
        name = "blob"
        addChild(BlobNode.makeVisual(tier: tier, theme: theme))
        let body = SKPhysicsBody(circleOfRadius: tier.radius * 0.94)
        body.categoryBitMask = PhysicsCategory.blob
        body.contactTestBitMask = PhysicsCategory.blob
        body.collisionBitMask = PhysicsCategory.blob | PhysicsCategory.wall
        body.restitution = 0.22
        body.friction = 0.45
        body.linearDamping = 0.12
        body.allowsRotation = false
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func makeVisual(tier: BlobTier, theme: BlobTheme) -> SKNode {
        let node = GlassRenderer.mergeBlobNode(radius: tier.radius, tier: tier, theme: theme)
        node.name = "visual"
        return node
    }

    /// Re-skins the blob (theme change) without touching physics.
    func applyTheme(_ theme: BlobTheme) {
        childNode(withName: "visual")?.removeFromParent()
        addChild(BlobNode.makeVisual(tier: tier, theme: theme))
    }
}

/// Suika-style merge gameplay: tap to drop glowing glass blobs into the jar,
/// two identical touching blobs merge into the next tier, game over when the
/// pile rests above the dashed danger line for ~2 seconds.
final class MergeScene: SKScene, SKPhysicsContactDelegate {

    weak var delegate: MergeSceneDelegate?
    var theme: BlobTheme = .classic

    // Layout (computed in didMove from the scene size).
    private var world = SKNode()      // blobs, bursts, popups — cleared on reset
    private var statics = SKNode()    // jar walls/floor — survive reset
    private var jarLeft: CGFloat = 0
    private var jarRight: CGFloat = 0
    private var floorY: CGFloat = 0
    private var mouthY: CGFloat = 0
    private var dangerY: CGFloat = 0
    private var dropY: CGFloat = 0
    private var dangerLine: SKSpriteNode?

    // Run state.
    private var score = 0
    private var currentTier: BlobTier = .spark
    private var nextTier: BlobTier = .droplet
    private var lastDropAt: TimeInterval = -10
    private var lastUpdate: TimeInterval = 0
    private var dangerTime: TimeInterval = 0
    private var comboCount = 0
    private var lastMergeAt: TimeInterval = -10
    private var gameOver = false

    // MARK: - Setup

    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)

        addChild(statics)
        addChild(world)

        let bg = GlassRenderer.studioBackground(size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(bg)

        layoutJar()
        currentTier = .spark
        nextTier = BlobTier.randomDropTier()
        delegate?.mergeScene(self, didChangeScore: 0)
        delegate?.mergeScene(self, didChangeTiers: currentTier, next: nextTier)
    }

    private func layoutJar() {
        let sideMargin: CGFloat = 24
        jarLeft = sideMargin
        jarRight = size.width - sideMargin
        floorY = 96
        mouthY = size.height - 168   // below the SwiftUI HUD
        dangerY = mouthY - 120
        dropY = mouthY + 28

        let jarW = jarRight - jarLeft
        let midX = (jarLeft + jarRight) / 2

        // Frosted-glass jar outline.
        let jar = GlassRenderer.jarNode(rect: CGRect(x: jarLeft - 12, y: floorY - 12,
                                                     width: jarW + 24, height: mouthY + 24 - floorY + 12))
        addChild(jar)

        // Physics walls: floor + two sides, ending at the mouth so blobs can
        // be dropped in and the pile can rise above.
        func staticBody(at position: CGPoint, size: CGSize) {
            let node = SKNode()
            node.position = position
            let body = SKPhysicsBody(rectangleOf: size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.blob
            body.contactTestBitMask = 0
            node.physicsBody = body
            statics.addChild(node)
        }
        staticBody(at: CGPoint(x: midX, y: floorY - 8), size: CGSize(width: jarW + 40, height: 16))
        let wallH = mouthY + 60 - floorY
        staticBody(at: CGPoint(x: jarLeft - 6, y: floorY + wallH / 2), size: CGSize(width: 12, height: wallH))
        staticBody(at: CGPoint(x: jarRight + 6, y: floorY + wallH / 2), size: CGSize(width: 12, height: wallH))

        // Dashed danger line.
        let line = SKSpriteNode(texture: GlassRenderer.dashedLineTexture(width: jarW))
        line.position = CGPoint(x: midX, y: dangerY)
        line.zPosition = 5
        line.alpha = 0.85
        addChild(line)
        dangerLine = line
    }

    // MARK: - Dropping

    /// Drops the current blob at a scene-space x (clamped to the jar).
    func dropBlob(atX x: CGFloat) {
        guard !gameOver else { return }
        let now = CACurrentMediaTime()
        guard now - lastDropAt >= MergeGame.dropCooldown else { return }
        lastDropAt = now

        let r = currentTier.radius
        let cx = min(max(x, jarLeft + r), jarRight - r)
        let blob = BlobNode(tier: currentTier, theme: theme)
        blob.position = CGPoint(x: cx, y: dropY)
        world.addChild(blob)
        if let visual = blob.childNode(withName: "visual") {
            visual.setScale(0.6)
            visual.run(.scale(to: 1.0, duration: 0.18))
        }

        SoundManager.shared.play(.drop)
        Haptics.light()

        currentTier = nextTier
        nextTier = BlobTier.randomDropTier()
        delegate?.mergeScene(self, didChangeTiers: currentTier, next: nextTier)
    }

    // MARK: - Merging

    func didBegin(_ contact: SKPhysicsContact) {
        guard !gameOver,
              let a = contact.bodyA.node as? BlobNode,
              let b = contact.bodyB.node as? BlobNode,
              a.parent != nil, b.parent != nil,
              a.tier == b.tier, !a.merging, !b.merging
        else { return }
        a.merging = true
        b.merging = true
        mergeBlobs(a, b)
    }

    private func mergeBlobs(_ a: BlobNode, _ b: BlobNode) {
        let tier = a.tier
        let mid = CGPoint(x: (a.position.x + b.position.x) / 2,
                          y: (a.position.y + b.position.y) / 2)
        a.removeFromParent()
        b.removeFromParent()

        let now = CACurrentMediaTime()
        if now - lastMergeAt < MergeGame.comboWindow {
            comboCount += 1
        } else {
            comboCount = 1
        }
        lastMergeAt = now

        // Two Prisms annihilate: there is no tier 7, just a supernova.
        if tier == .prism {
            world.addChild(GlassRenderer.burst(at: mid, color: .white))
            world.addChild(GlassRenderer.burst(at: mid, color: theme.skColor(for: .prism)))
            addScore(MergeGame.supernovaBonus, at: mid, label: "SUPERNOVA!")
            SoundManager.shared.play(.combo)
            Haptics.heavy()
            shake(intensity: 9)
            return
        }

        guard let next = BlobTier(rawValue: tier.rawValue + 1) else { return }
        let blob = BlobNode(tier: next, theme: theme)
        blob.position = mid
        world.addChild(blob)
        if let visual = blob.childNode(withName: "visual") {
            visual.setScale(0.55)
            visual.run(.sequence([
                .scale(to: 1.12, duration: 0.12),
                .scale(to: 1.0, duration: 0.10),
            ]))
        }

        world.addChild(GlassRenderer.burst(at: mid, color: theme.skColor(for: next)))
        let points = next.scoreValue * comboCount
        addScore(points, at: mid, label: comboCount >= 3 ? "MERGE x\(comboCount)" : nil)

        SoundManager.shared.play(.merge(tier: next.rawValue))
        switch next.rawValue {
        case 0...1: Haptics.light()
        case 2...3: Haptics.medium()
        default: Haptics.heavy()
        }
        if next.rawValue >= 3 {
            shake(intensity: 4)
        }
        if next == .prism {
            let label = GlassRenderer.popupLabel(text: "PRISM!", color: .white, fontSize: 46)
            label.position = CGPoint(x: mid.x, y: mid.y + 40)
            world.addChild(label)
            SoundManager.shared.play(.combo)
            Haptics.success()
        }
    }

    private func addScore(_ points: Int, at point: CGPoint, label: String?) {
        score += points
        delegate?.mergeScene(self, didChangeScore: score)
        let popup: SKLabelNode
        if let label {
            popup = GlassRenderer.popupLabel(text: label, color: .white, fontSize: 34)
        } else {
            popup = GlassRenderer.popupLabel(text: "+\(points)", color: SKColor(white: 1, alpha: 0.85),
                                             fontSize: 22)
        }
        popup.position = point
        world.addChild(popup)
    }

    /// Gentle shake-lite on big merges: a quick jitter of the world node.
    private func shake(intensity: CGFloat) {
        world.removeAction(forKey: "shake")
        var moves: [SKAction] = []
        for _ in 0..<4 {
            moves.append(.moveBy(x: CGFloat.random(in: -intensity...intensity),
                                 y: CGFloat.random(in: -intensity...intensity),
                                 duration: 0.04))
        }
        moves.append(.move(to: .zero, duration: 0.05))
        world.run(.sequence(moves), withKey: "shake")
    }

    // MARK: - Danger line & game over

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate > 0 ? min(currentTime - lastUpdate, 0.1) : 0
        lastUpdate = currentTime
        guard !gameOver else { return }

        let blobs = world.children.compactMap { $0 as? BlobNode }
        for blob in blobs where blob.position.y > size.height + 120 {
            blob.removeFromParent() // safety: never lose a blob off-screen
        }

        // A blob counts against the line only when it is nearly settled —
        // freshly dropped blobs fall through the zone too fast to count.
        let crowded = blobs.contains { blob in
            guard let v = blob.physicsBody?.velocity else { return false }
            return blob.position.y + blob.tier.radius * 0.5 > dangerY
                && hypot(v.dx, v.dy) < 70
        }
        if crowded {
            dangerTime += dt
            dangerLine?.alpha = 0.55 + 0.45 * abs(sin(dangerTime * 9))
        } else {
            dangerTime = 0
            dangerLine?.alpha = 0.85
        }
        if dangerTime >= MergeGame.dangerHoldTime {
            triggerGameOver()
        }
    }

    private func triggerGameOver() {
        gameOver = true
        isPaused = true // freeze the pile behind the game-over overlay
        SoundManager.shared.play(.gameOver)
        Haptics.error()
        delegate?.mergeSceneDidEnd(self)
    }

    // MARK: - Run control (called from SwiftUI)

    func reset() {
        isPaused = false
        world.removeAllChildren()
        score = 0
        comboCount = 0
        dangerTime = 0
        gameOver = false
        lastDropAt = -10
        lastMergeAt = -10
        currentTier = .spark
        nextTier = BlobTier.randomDropTier()
        dangerLine?.alpha = 0.85
        delegate?.mergeScene(self, didChangeScore: 0)
        delegate?.mergeScene(self, didChangeTiers: currentTier, next: nextTier)
    }

    /// Rewarded-ad Continue: clears the top 3 rows of blobs and resumes.
    /// Rows are 72pt horizontal bands, counted from the highest blob down.
    func resumeByClearingTopRows() {
        let blobs = world.children.compactMap { $0 as? BlobNode }
            .sorted { $0.position.y > $1.position.y }
        let band: CGFloat = 72
        var rows = 0
        var lastY: CGFloat? = nil
        for blob in blobs {
            if let ly = lastY, abs(blob.position.y - ly) < band {
                // Same row as the previous blob.
            } else {
                rows += 1
                lastY = blob.position.y
            }
            if rows > 3 { break }
            world.addChild(GlassRenderer.burst(at: blob.position,
                                               color: theme.skColor(for: blob.tier)))
            blob.removeFromParent()
        }
        dangerTime = 0
        gameOver = false
        isPaused = false
        SoundManager.shared.play(.resume)
    }

    /// Re-skins every blob in the jar (theme purchase/selection).
    func applyTheme(_ newTheme: BlobTheme) {
        theme = newTheme
        for case let blob as BlobNode in world.children {
            blob.applyTheme(newTheme)
        }
    }
}
