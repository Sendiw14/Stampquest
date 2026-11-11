import Foundation

/// What the person loves to find (onboarding prompt 02). Six tiles, shown in this order.
nonisolated enum Interest: String, CaseIterable, Codable, Hashable, Sendable {
    case cities, coasts, mountains, food, history, hiddenGems

    /// Key fragment for `onboarding.interests.<key>.name` and `.desc`.
    var key: String { self == .hiddenGems ? "gems" : rawValue }
    var nameKey: String { "onboarding.interests." + key + ".name" }
    var descKey: String { "onboarding.interests." + key + ".desc" }
}
