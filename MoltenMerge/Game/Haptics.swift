import UIKit

/// Lightweight haptic accents. Every generator is created on demand and fired
/// on the main thread; call sites are already main-thread (UI / SpriteKit).
/// `enabled` is user-toggleable in Settings; when off, every call is a no-op.
enum Haptics {
    static var enabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: MergeGame.hapticsEnabledKey) == nil {
                return true // default on for first launch
            }
            return UserDefaults.standard.bool(forKey: MergeGame.hapticsEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: MergeGame.hapticsEnabledKey) }
    }

    static func light() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func medium() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    static func heavy() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    static func success() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func error() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    static func selection() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
