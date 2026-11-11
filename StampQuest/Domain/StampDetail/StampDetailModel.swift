import Foundation

/// The four situations of a stamp on its detail screen. "Removed" is a transition, not a state: after a removal the stamp is
/// simply `notCollected`. Derived from canonical records only.
nonisolated enum StampDetailState: Equatable, Sendable {
    case notCollected, wishlisted, collectedManual, collectedVerified

    init(_ state: StampState) {
        switch state {
        case .notCollected: self = .notCollected
        case .wishlisted: self = .wishlisted
        case .collected: self = .collectedManual
        case .verified: self = .collectedVerified
        }
    }

    var isCollected: Bool { self == .collectedManual || self == .collectedVerified }
    var isVerified: Bool { self == .collectedVerified }

    /// Every legal single step. A verified stamp never goes back to by hand; the only way out is Remove.
    func canMove(to next: StampDetailState) -> Bool {
        switch (self, next) {
        case (.notCollected, .wishlisted), (.wishlisted, .notCollected): true
        case (.notCollected, .collectedManual), (.wishlisted, .collectedManual): true
        case (.collectedManual, .collectedVerified): true
        case (.collectedManual, .notCollected), (.collectedVerified, .notCollected): true
        default: false
        }
    }
}

nonisolated struct StampRelatedItem: Identifiable, Hashable, Sendable {
    let destinationID: String
    let name: String
    let state: StampDetailState

    var id: String { destinationID }
}

nonisolated struct StampCollectionSummary: Equatable, Sendable {
    let collectionID: String
    let title: String
    /// Collected stamps in this collection (by hand or verified, never wishlisted).
    let have: Int
    let total: Int
}

nonisolated enum StampDetailDerived {
    /// The collection the stamp belongs to: the first one in catalog order that contains it.
    static func collection(of destinationID: String, catalog: Catalog) -> StampCollection? {
        catalog.collections(containing: destinationID).first
    }

    static func summary(of destinationID: String, catalog: Catalog, snapshot: PassportSnapshot) -> StampCollectionSummary? {
        guard let collection = collection(of: destinationID, catalog: catalog) else { return nil }
        let progress = CollectionProgress.make(for: collection, snapshot: snapshot)
        return StampCollectionSummary(collectionID: collection.id, title: collection.title, have: progress.collected, total: progress.total)
    }

    /// Up to four other stamps of the same collection, in catalog order. Never ranked by anything.
    static func related(to destinationID: String, catalog: Catalog, snapshot: PassportSnapshot, limit: Int = 4) -> [StampRelatedItem] {
        guard let collection = collection(of: destinationID, catalog: catalog) else { return [] }
        return collection.destinationIDs
            .filter { $0 != destinationID }
            .compactMap { id -> StampRelatedItem? in
                guard let destination = catalog.destination(id: id) else { return nil }
                return StampRelatedItem(destinationID: id, name: destination.name, state: StampDetailState(snapshot.state(of: id)))
            }
            .prefix(limit).map { $0 }
    }
}
