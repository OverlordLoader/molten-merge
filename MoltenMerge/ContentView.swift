import SwiftUI

/// Root view: hosts the game. The game view model is created once here so the
/// SpriteKit scene (and the run state) survives view re-renders.
struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        GameView(viewModel: viewModel)
    }
}
