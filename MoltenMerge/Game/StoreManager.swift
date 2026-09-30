import Foundation
import Combine
import StoreKit

/// StoreKit 2 purchases for Molten Merge. Everything goes through Apple — no
/// external billing, no web links. Works offline for owned entitlements
/// (persisted locally); purchases themselves need a network connection.
///
/// Products (must match App Store Connect exactly):
/// - app.moltenmerge.game.removeads ..... non-consumable $4.99 — Remove Ads
/// - app.moltenmerge.game.theme.sakura .. non-consumable $1.99 — Sakura Theme
/// - app.moltenmerge.game.theme.nebula .. non-consumable $1.99 — Nebula Theme
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // Product IDs — these MUST match the products created in App Store Connect.
    static let removeAdsID = "app.moltenmerge.game.removeads"
    static let sakuraThemeID = "app.moltenmerge.game.theme.sakura"
    static let nebulaThemeID = "app.moltenmerge.game.theme.nebula"

    static let allProductIDs = [removeAdsID, sakuraThemeID, nebulaThemeID]

    @Published private(set) var removeAds = false
    @Published private(set) var ownedThemeIDs: Set<String> = []
    @Published private(set) var selectedThemeID: String = BlobTheme.classic.rawValue
    @Published private(set) var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var lastError: String?

    private var updateListener: Task<Void, Error>?

    private enum Keys {
        static let removeAds = "moltenmerge.store.removeAds"
        static let ownedThemes = "moltenmerge.store.ownedThemes"
        static let selectedTheme = "moltenmerge.store.selectedTheme"
    }

    private init() {
        let d = UserDefaults.standard
        removeAds = d.bool(forKey: Keys.removeAds)
        ownedThemeIDs = Set(d.stringArray(forKey: Keys.ownedThemes) ?? [])
        let saved = d.string(forKey: Keys.selectedTheme) ?? BlobTheme.classic.rawValue
        selectedThemeID = ownedThemeIDs.contains(saved) || saved == BlobTheme.classic.rawValue
            ? saved : BlobTheme.classic.rawValue
        // Listen for transactions that complete outside the app
        // (e.g. approved on another device, Ask to Buy, refunds).
        updateListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleUpdate(result)
            }
        }
        Task { await refreshEntitlements() }
    }

    var selectedTheme: BlobTheme {
        BlobTheme(rawValue: selectedThemeID) ?? .classic
    }

    func isThemeOwned(_ theme: BlobTheme) -> Bool {
        theme == .classic || ownedThemeIDs.contains(theme.rawValue)
    }

    /// Selects an owned theme (Classic is always owned). No-op for locked themes.
    func selectTheme(_ theme: BlobTheme) {
        guard isThemeOwned(theme) else { return }
        selectedThemeID = theme.rawValue
        UserDefaults.standard.set(theme.rawValue, forKey: Keys.selectedTheme)
    }

    // MARK: - Products

    @MainActor
    func requestProducts() async {
        do {
            products = try await Product.products(for: Self.allProductIDs)
        } catch {
            lastError = "Couldn't load store products. Check your connection and try again."
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    var removeAdsProduct: Product? { product(for: Self.removeAdsID) }

    func themeProduct(_ theme: BlobTheme) -> Product? {
        guard let id = theme.productID else { return nil }
        return product(for: id)
    }

    // MARK: - Purchase

    @MainActor
    func purchase(_ product: Product) async {
        guard !purchaseInProgress else { return }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                try await handleVerified(verification)
                lastError = nil
            case .userCancelled, .pending:
                break // no error to show; pending resolves via Transaction.updates
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. Please try again."
        }
    }

    @MainActor
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    // MARK: - Verification & entitlements

    private func handleUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            try await handleVerified(result)
        } catch {
            // Unverified transactions are ignored — never grant on them.
        }
    }

    private func handleVerified(_ verification: VerificationResult<Transaction>) async throws {
        switch verification {
        case .verified(let transaction):
            await MainActor.run { self.apply(transaction) }
            await transaction.finish()
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    @MainActor
    private func apply(_ transaction: Transaction) {
        switch transaction.productID {
        case Self.removeAdsID:
            removeAds = true
            UserDefaults.standard.set(true, forKey: Keys.removeAds)
        case Self.sakuraThemeID:
            ownedThemeIDs.insert(BlobTheme.sakura.rawValue)
            UserDefaults.standard.set(Array(ownedThemeIDs), forKey: Keys.ownedThemes)
        case Self.nebulaThemeID:
            ownedThemeIDs.insert(BlobTheme.nebula.rawValue)
            UserDefaults.standard.set(Array(ownedThemeIDs), forKey: Keys.ownedThemes)
        default:
            break
        }
    }

    /// Re-reads current entitlements (covers restores and refunds).
    /// A revoked Remove Ads (refund) brings ads back; a revoked theme is
    /// un-owned and un-selected.
    func refreshEntitlements() async {
        var entitledRemoveAds = false
        var entitledThemes = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                switch transaction.productID {
                case Self.removeAdsID:
                    entitledRemoveAds = true
                case Self.sakuraThemeID:
                    entitledThemes.insert(BlobTheme.sakura.rawValue)
                case Self.nebulaThemeID:
                    entitledThemes.insert(BlobTheme.nebula.rawValue)
                default:
                    break
                }
            }
        }
        await MainActor.run {
            self.removeAds = entitledRemoveAds
            UserDefaults.standard.set(entitledRemoveAds, forKey: Keys.removeAds)
            self.ownedThemeIDs = entitledThemes
            UserDefaults.standard.set(Array(entitledThemes), forKey: Keys.ownedThemes)
            if !self.isThemeOwned(self.selectedTheme) {
                self.selectedThemeID = BlobTheme.classic.rawValue
                UserDefaults.standard.set(BlobTheme.classic.rawValue, forKey: Keys.selectedTheme)
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
