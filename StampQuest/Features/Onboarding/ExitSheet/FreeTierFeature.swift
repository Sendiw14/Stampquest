import Foundation

/// The rows of "what the free passport keeps". A row is shown only while `isShipped`, and each claim was checked against the app:
/// collecting stamps (Discover, Passport), wishlist, map, memories and trips (their own tabs and screens), and offline use with no account
/// (the app has no sign-in and its catalogue is bundled).
nonisolated enum FreeTierFeature: CaseIterable, Sendable {
    case collect, tools, offline

    var isShipped: Bool { true }

    /// The rows to draw: unshipped ones are dropped. With none, the card is hidden.
    static func shipped(_ all: [FreeTierFeature] = allCases, isShipped: (FreeTierFeature) -> Bool = { $0.isShipped }) -> [FreeTierFeature] {
        all.filter(isShipped)
    }

    var key: String {
        switch self {
        case .collect: "exit.free.collect"
        case .tools: "exit.free.tools"
        case .offline: "exit.free.offline"
        }
    }
}
