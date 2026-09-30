import SwiftUI

/// Game-over overlay: score, best, rewarded-ad Continue (once per run), and
/// Play Again (which shows an interstitial first, only when one is due).
struct GameOverView: View {
    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject var ads: AdsManager
    @EnvironmentObject var store: StoreManager
    @State private var adUnavailable = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GAME OVER")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                if viewModel.isNewBest {
                    Text("NEW BEST!")
                        .font(.headline.weight(.bold))
                        .foregroundColor(Palette.best.swiftUIColor)
                }

                Text("\(viewModel.score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.score.swiftUIColor)

                Text("Best \(viewModel.best)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                // Rewarded Continue: once per run, hidden for Remove-Ads owners
                // (there is no ad to watch) and after it has been used.
                if !store.removeAds && !viewModel.continueUsed {
                    Button {
                        SoundManager.shared.play(.click)
                        ads.showRewarded { earned in
                            if earned {
                                viewModel.continueAfterReward()
                            } else {
                                adUnavailable = true
                            }
                        }
                    } label: {
                        Label("Continue — Watch Ad", systemImage: "play.rectangle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ads.rewardedReady ? Palette.premium.swiftUIColor : .gray.opacity(0.5))
                            .cornerRadius(14)
                    }
                    .disabled(!ads.rewardedReady)

                    if adUnavailable {
                        Text("No ad available right now — check your connection.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    } else if !ads.rewardedReady {
                        Text("Loading reward ad…")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("Clears the top 3 rows. Once per run.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Button {
                    ads.showInterstitialIfDue {
                        viewModel.restart()
                    }
                } label: {
                    Label("Play Again", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Palette.score.swiftUIColor)
                        .cornerRadius(14)
                }
            }
            .padding(28)
            .background(Color(white: 0.12))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 40)
        }
    }
}
