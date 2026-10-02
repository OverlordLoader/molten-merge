import SwiftUI

@main
struct MoltenMergeApp: App {
    @StateObject private var store = StoreManager.shared
    @StateObject private var ads = AdsManager.shared

    init() {
        // Google Mobile Ads: test IDs in DEBUG, real IDs (set by Henry) in release.
        AdsManager.shared.configure()
        // Pre-load App Store products so Settings shows live prices.
        Task { await StoreManager.shared.requestProducts() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(ads)
                .preferredColorScheme(.dark)
        }
    }
}
