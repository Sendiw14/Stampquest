import Foundation

/// A catalog interest (a destination category) as the Discover rail shows it.
nonisolated struct DiscoverInterest: Identifiable, Hashable, Sendable {
    let category: DestinationCategory
    let count: Int
    /// Chosen in onboarding.
    let isPick: Bool
    /// The stamp that stands for the interest: the first place of the category in catalog order.
    let artDestinationID: String

    var id: String { category.rawValue }
}

nonisolated extension Interest {
    /// The catalog categories an onboarding interest stands for. The onboarding tiles are broader than the catalog's ten
    /// categories, so one tile can cover several.
    var categories: Set<DestinationCategory> {
        switch self {
        case .cities: [.city]
        case .coasts: [.beach, .island]
        case .mountains: [.nature, .nationalPark]
        case .food: [.foodCulture]
        case .history: [.landmark, .architecture, .museum]
        case .hiddenGems: [.hiddenGem]
        }
    }
}

nonisolated struct DiscoverCollectionRow: Identifiable, Hashable, Sendable {
    let collection: StampCollection
    let memberCount: Int
    let collectedCount: Int
    /// The first three places by collection order.
    let coverIDs: [String]

    var id: String { collection.id }
}

/// Everything the Discover page shows, derived from the catalog and the canonical records (rule 12). Nothing here is stored.
nonisolated struct DiscoverDerived: Sendable {
    let placesToCollect: [Destination]
    let editorsPick: Destination?
    /// The stamps of the hero fan: the editor's pick first, then another featured place.
    let fanIDs: [String]
    let interests: [DiscoverInterest]
    let collections: [DiscoverCollectionRow]
    /// Recently viewed places, newest first, at most `recentLimit`.
    let recents: [String]
    /// Saved places that are not collected, newest saved first.
    let wishlist: [WishlistEntry]

    static let recentLimit = 3

    static func make(catalog: Catalog, snapshot: PassportSnapshot, recentIDs: [String], picks: Set<Interest>) -> DiscoverDerived {
        let state: (String) -> StampState = snapshot.state(of:)
        let toCollect = catalog.destinations.filter { !state($0.id).isInPassport }

        let pick = editorsPick(in: catalog)
        var fan: [String] = []
        if let pick { fan.append(pick.id) }
        if let second = secondFeatured(in: catalog, after: pick) { fan.append(second.id) }

        let pickedCategories = picks.reduce(into: Set<DestinationCategory>()) { $0.formUnion($1.categories) }
        let all = DestinationCategory.allCases.compactMap { category -> DiscoverInterest? in
            let members = catalog.destinations.filter { $0.category == category }
            guard let first = members.first else { return nil }
            return DiscoverInterest(category: category, count: members.count, isPick: pickedCategories.contains(category), artDestinationID: first.id)
        }
        let interests = all.filter(\.isPick) + all.filter { !$0.isPick }

        let progress = CollectionProgress.all(catalog: catalog, snapshot: snapshot)
        let collections = progress.map {
            DiscoverCollectionRow(collection: $0.collection, memberCount: $0.total, collectedCount: $0.collected,
                                  coverIDs: Array($0.collection.destinationIDs.filter { catalog.destination(id: $0) != nil }.prefix(3)))
        }

        let wishlist = snapshot.wishlist
            .filter { !state($0.destinationID).isInPassport && catalog.destination(id: $0.destinationID) != nil }
            .sorted { $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : $0.destinationID < $1.destinationID }

        let recents = recentIDs.filter { catalog.destination(id: $0) != nil }

        return DiscoverDerived(placesToCollect: toCollect, editorsPick: pick, fanIDs: fan, interests: interests,
                               collections: collections, recents: Array(recents.prefix(recentLimit)), wishlist: wishlist)
    }

    // MARK: Editor's pick

    /// The featured places in a fixed order, so the pick never depends on anything the person does.
    private static func featuredRing(in catalog: Catalog) -> [Destination] { catalog.featured.sorted { $0.id < $1.id } }

    /// One featured place per catalog version, picked deterministically from the catalog's own featured flag.
    static func editorsPick(in catalog: Catalog) -> Destination? {
        let ring = featuredRing(in: catalog)
        guard !ring.isEmpty else { return nil }
        let seed = catalog.version.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return ring[seed % ring.count]
    }

    private static func secondFeatured(in catalog: Catalog, after pick: Destination?) -> Destination? {
        let ring = featuredRing(in: catalog)
        guard ring.count > 1, let pick, let index = ring.firstIndex(of: pick) else { return nil }
        return ring[(index + 1) % ring.count]
    }
}
