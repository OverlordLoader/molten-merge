import SwiftUI
import SpriteKit

/// Bridges the SpriteKit scene and SwiftUI. Owns score/best/run state and
/// forwards taps into the scene. All scene callbacks arrive on the main thread.
@MainActor
final class GameViewModel: ObservableObject, MergeSceneDelegate {
    @Published var score = 0
    @Published var best: Int
    @Published var currentTier: BlobTier = .spark
    @Published var nextTier: BlobTier = .droplet
    @Published var isGameOver = false
    @Published var isNewBest = false
    @Published var showSettings = false
    @Published var continueUsed = false

    private var scene: MergeScene?
    private var sceneSize: CGSize = .zero

    init() {
        best = UserDefaults.standard.integer(forKey: MergeGame.bestScoreKey)
    }

    /// Returns the (cached) scene for this view size, creating it on first call.
    func scene(for size: CGSize) -> MergeScene {
        if let scene, sceneSize == size { return scene }
        let scene = MergeScene(size: size)
        scene.scaleMode = .resizeFill
        scene.delegate = self
        scene.theme = StoreManager.shared.selectedTheme
        self.scene = scene
        self.sceneSize = size
        return scene
    }

    /// Drops a blob at a SwiftUI view point (origin top-left).
    func drop(at point: CGPoint, in size: CGSize) {
        guard !isGameOver else { return }
        scene?.dropBlob(atX: point.x)
    }

    func applyTheme(_ theme: BlobTheme) {
        scene?.applyTheme(theme)
    }

    func restart() {
        score = 0
        isNewBest = false
        isGameOver = false
        continueUsed = false
        SoundManager.shared.play(.click)
        Haptics.selection()
        scene?.reset()
    }

    func continueAfterReward() {
        continueUsed = true
        isGameOver = false
        scene?.resumeByClearingTopRows()
    }

    // MARK: - MergeSceneDelegate

    func mergeScene(_ scene: MergeScene, didChangeScore score: Int) {
        self.score = score
        if score > best {
            best = score
            isNewBest = true
            UserDefaults.standard.set(best, forKey: MergeGame.bestScoreKey)
        }
    }

    func mergeScene(_ scene: MergeScene, didChangeTiers current: BlobTier, next: BlobTier) {
        currentTier = current
        nextTier = next
    }

    func mergeSceneDidEnd(_ scene: MergeScene) {
        isGameOver = true
        AdsManager.shared.recordGameOver()
    }
}

// MARK: - Game view

struct GameView: View {
    @StateObject var viewModel: GameViewModel
    @EnvironmentObject var store: StoreManager

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                SpriteView(scene: viewModel.scene(for: geo.size))
                    .onTapGesture { location in
                        viewModel.drop(at: location, in: geo.size)
                    }
                HUDView(viewModel: viewModel)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
        .overlay {
            if viewModel.isGameOver {
                GameOverView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isGameOver)
    }
}

// MARK: - HUD

private struct HUDView: View {
    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject var store: StoreManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Palette.score.swiftUIColor)
                Text("\(viewModel.score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                HStack(spacing: 4) {
                    Text("BEST")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.55))
                    Text("\(viewModel.best)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Palette.best.swiftUIColor)
                }
            }
            Spacer()
            VStack(spacing: 4) {
                Text("NEXT")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.55))
                HStack(spacing: 6) {
                    BlobPreviewView(tier: viewModel.currentTier,
                                    theme: store.selectedTheme, size: 54)
                    BlobPreviewView(tier: viewModel.nextTier,
                                    theme: store.selectedTheme, size: 34)
                }
            }
            Button {
                SoundManager.shared.play(.click)
                Haptics.selection()
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(10)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

// MARK: - Blob preview (tiny SpriteKit scene reusing the real renderer)

struct BlobPreviewView: View {
    let tier: BlobTier
    let theme: BlobTheme
    let size: CGFloat

    var body: some View {
        SpriteView(scene: makeScene(), options: [.allowsTransparency])
            .frame(width: size, height: size)
    }

    private func makeScene() -> SKScene {
        let scene = SKScene(size: CGSize(width: size, height: size))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        let node = GlassRenderer.mergeBlobNode(radius: size * 0.30, tier: tier, theme: theme)
        node.position = CGPoint(x: size / 2, y: size / 2)
        scene.addChild(node)
        return scene
    }
}
