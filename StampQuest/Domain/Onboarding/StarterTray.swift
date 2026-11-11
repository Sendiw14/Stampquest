import Foundation

/// Ranks the starter stamps for the First stamp screen.
///
/// Limitation: only Paris, Kyoto and Santorini have artwork, so the result is always exactly these three in ranked
/// order. Do not add stamps here until new art exists.
nonisolated enum StarterTray {
    /// Weight of each interest for each stamp (prompt 02 section 7).
    static let weights: [String: [Interest: Int]] = [
        StampDestination.paris.id: [.cities: 3, .food: 1, .history: 1],
        StampDestination.kyoto.id: [.cities: 1, .mountains: 1, .food: 1, .history: 2, .hiddenGems: 2],
        StampDestination.santorini.id: [.coasts: 3, .history: 1, .hiddenGems: 1],
    ]

    static func score(_ destination: StampDestination, for interests: Set<Interest>) -> Int {
        interests.reduce(0) { $0 + (weights[destination.id]?[$1] ?? 0) }
    }

    /// Score descending, ties by catalog order; empty interests return catalog order.
    static func rank(for interests: Set<Interest>, from catalog: [StampDestination] = StampDestination.catalog) -> [StampDestination] {
        guard !interests.isEmpty else { return catalog }
        return catalog.enumerated()
            .sorted { l, r in
                let (a, b) = (score(l.element, for: interests), score(r.element, for: interests))
                return a != b ? a > b : l.offset < r.offset
            }
            .map(\.element)
    }
}
