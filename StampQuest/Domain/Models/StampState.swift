import Foundation

/// How a stamp relates to the user's passport. Exactly one applies at a time.
///
/// - `notCollected`: nothing recorded.
/// - `wishlisted`: saved for later. **Not** a collected stamp.
/// - `collected`: in the passport, recorded manually. **Not** a verified visit.
/// - `verified`: in the passport and the user's presence was checked on location.
nonisolated enum StampState: String, Codable, CaseIterable, Sendable {
    case notCollected, wishlisted, collected, verified

    var isInPassport: Bool { self == .collected || self == .verified }

    var title: String {
        switch self {
        case .notCollected: String(localized: "Not collected")
        case .wishlisted: String(localized: "On your wishlist")
        case .collected: String(localized: "Collected")
        case .verified: String(localized: "Verified visit")
        }
    }

    /// Short label for badges.
    var shortTitle: String {
        switch self {
        case .notCollected: String(localized: "Not collected")
        case .wishlisted: String(localized: "Wishlist")
        case .collected: String(localized: "Collected")
        case .verified: String(localized: "Verified")
        }
    }

    var symbolName: String {
        switch self {
        case .notCollected: "circle.dashed"
        case .wishlisted: "heart"
        case .collected: "checkmark.seal"
        case .verified: "location.circle.fill"
        }
    }
}

/// How a stamp entered the passport.
nonisolated enum CollectionMethod: String, Codable, Sendable {
    /// The user collected the stamp without any location check.
    case manual
    /// The user collected the stamp through a successful location verification.
    case verified
}
