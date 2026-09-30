import SwiftUI

/// Settings: Remove Ads purchase, theme shop (Sakura / Nebula), Restore
/// Purchases, and sound/haptics toggles. Every row is live — no dead buttons.
struct SettingsView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    removeAdsRow
                    ForEach([BlobTheme.sakura, BlobTheme.nebula]) { theme in
                        themeRow(theme)
                    }
                } header: {
                    Text("Premium")
                } footer: {
                    Text("Purchases are one-time, yours forever, and sync via your Apple ID.")
                }

                Section("Preferences") {
                    Toggle("Sound Effects", isOn: Binding(
                        get: { SoundManager.shared.enabled },
                        set: { SoundManager.shared.enabled = $0 }
                    ))
                    Toggle("Haptics", isOn: Binding(
                        get: { Haptics.enabled },
                        set: { Haptics.enabled = $0 }
                    ))
                }

                Section {
                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .disabled(store.purchaseInProgress)
                } footer: {
                    Text("Already bought Remove Ads or a theme on another device? Restore them here.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text("app.moltenmerge.game")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await store.requestProducts()
            }
            .onChange(of: store.lastError) { _, newValue in
                showError = newValue != nil
            }
            .alert("Store", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    store.lastError = nil
                }
            } message: {
                Text(store.lastError ?? "Something went wrong.")
            }
        }
    }

    // MARK: - Rows

    private var removeAdsRow: some View {
        Button {
            guard !store.removeAds, !store.purchaseInProgress,
                  let product = store.removeAdsProduct else { return }
            SoundManager.shared.play(.click)
            Task { await store.purchase(product) }
        } label: {
            HStack {
                Image(systemName: "nosign")
                    .foregroundColor(Palette.premium.swiftUIColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove Ads")
                        .foregroundColor(.primary)
                    Text("No more interstitials or reward prompts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if store.removeAds {
                    Label("Owned", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                } else if let product = store.removeAdsProduct {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.premium.swiftUIColor)
                } else {
                    Text("Loading…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(store.removeAds || store.purchaseInProgress)
    }

    private func themeRow(_ theme: BlobTheme) -> some View {
        let owned = store.isThemeOwned(theme)
        let selected = store.selectedTheme == theme
        return Button {
            SoundManager.shared.play(.click)
            Haptics.selection()
            if owned {
                store.selectTheme(theme)
            } else if let product = store.themeProduct(theme), !store.purchaseInProgress {
                Task { await store.purchase(product) }
            }
        } label: {
            HStack(spacing: 12) {
                // Skin preview: the six tier colors for this theme.
                HStack(spacing: -8) {
                    ForEach(BlobTier.allCases) { tier in
                        Circle()
                            .fill(theme.swiftUIColor(for: tier))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(theme.displayName) Theme")
                        .foregroundColor(.primary)
                    Text(theme.tagline)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selected {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                } else if owned {
                    Text("Select")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.score.swiftUIColor)
                } else if let product = store.themeProduct(theme) {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.premium.swiftUIColor)
                } else {
                    Text(theme.fallbackPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(store.purchaseInProgress && !owned)
    }
}
