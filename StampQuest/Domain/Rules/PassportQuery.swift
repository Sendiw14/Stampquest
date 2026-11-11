import Foundation

nonisolated enum PassportSort: String, CaseIterable, Identifiable, Sendable {
    case recentlyCollected, alphabetical, country, collection, verifiedFirst, favoritesFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyCollected: String(localized: "Recently collected")
        case .alphabetical: String(localized: "A to Z")
        case .country: String(localized: "Country")
        case .collection: String(localized: "Collection")
        case .verifiedFirst: String(localized: "Verified first")
        case .favoritesFirst: String(localized: "Favorites first")
        }
    }

    /// The label on the sort chip.
    var shortTitle: String {
        switch self {
        case .recentlyCollected: String(localized: "Recent")
        case .alphabetical: String(localized: "A to Z")
        case .country: String(localized: "Country")
        case .collection: String(localized: "Collection")
        case .verifiedFirst: String(localized: "Verified")
        case .favoritesFirst: String(localized: "Favorites")
        }
    }
}

nonisolated enum PassportGrouping: String, CaseIterable, Identifiable, Sendable {
    case none, region, country, collection, trip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "None")
        case .region: String(localized: "Region")
        case .country: String(localized: "Country")
        case .collection: String(localized: "Collection")
        case .trip: String(localized: "Trip")
        }
    }
}

/// Sort and filter settings for the passport. Filters genuinely change the data set; they combine with AND across
/// groups and OR within one. `activeFilterCount` counts groups, not values.
nonisolated struct PassportQuery: Equatable, Sendable {
    var sort: PassportSort = .recentlyCollected
    var onlyVerified = false
    var onlyFavorites = false
    var countryCodes: Set<String> = []
    var collectionIDs: Set<String> = []
    /// Not offered on the Passport tab; kept for callers that search the passport.
    var searchText = ""

    var activeFilterCount: Int {
        [onlyVerified, onlyFavorites, !countryCodes.isEmpty, !collectionIDs.isEmpty, !searchText.isEmpty].filter { $0 }.count
    }

    var hasActiveFilters: Bool { activeFilterCount > 0 }

    /// True when nothing differs from the default view (the sheet's Reset is dimmed).
    var isDefault: Bool { self == PassportQuery() }

    /// Clears the filters and keeps the sort.
    mutating func clearFilters() { self = PassportQuery(sort: sort) }

    mutating func remove(_ kind: PassportFilterChip.Kind) {
        switch kind {
        case .verified: onlyVerified = false
        case .favorites: onlyFavorites = false
        case .country(let code): countryCodes.remove(code)
        case .collection(let id): collectionIDs.remove(id)
        }
    }

    /// One chip per active value: verified, favorites, countries A to Z, collections in display order.
    func chips(catalog: Catalog) -> [PassportFilterChip] {
        var chips: [PassportFilterChip] = []
        if onlyVerified { chips.append(PassportFilterChip(kind: .verified, title: String(localized: "Verified"))) }
        if onlyFavorites { chips.append(PassportFilterChip(kind: .favorites, title: String(localized: "Favorites"))) }
        chips += countryCodes.map { PassportFilterChip(kind: .country($0), title: CountryInfo.name(for: $0)) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        chips += catalog.collections.filter { collectionIDs.contains($0.id) }.map { PassportFilterChip(kind: .collection($0.id), title: $0.title) }
        return chips
    }

    func apply(to stamps: [CollectedStamp], catalog: Catalog) -> [CollectedStamp] {
        var result = stamps
        if onlyVerified { result = result.filter(\.isVerified) }
        if onlyFavorites { result = result.filter(\.isFavorite) }
        if !countryCodes.isEmpty { result = result.filter { countryCodes.contains($0.countryCode) } }
        if !collectionIDs.isEmpty {
            let members = Set(collectionIDs.compactMap { catalog.collection(id: $0) }.flatMap(\.destinationIDs))
            result = result.filter { members.contains($0.destinationID) }
        }
        let tokens = CatalogSearch.tokens(searchText)
        if !tokens.isEmpty {
            result = result.filter { stamp in
                let haystack = CatalogSearch.normalize(stamp.title + " " + (catalog.destination(id: stamp.destinationID).map { "\($0.landmark) \($0.countryName)" } ?? ""))
                return tokens.allSatisfy { haystack.contains($0) }
            }
        }
        return sorted(result, catalog: catalog)
    }

    /// Ties always fall to the collection date, newest first.
    private func sorted(_ stamps: [CollectedStamp], catalog: Catalog) -> [CollectedStamp] {
        func name(_ s: CollectedStamp) -> String { catalog.destination(id: s.destinationID)?.name ?? s.title }
        func country(_ s: CollectedStamp) -> String { CountryInfo.name(for: s.countryCode) }
        let byRecent: (CollectedStamp, CollectedStamp) -> Bool = { $0.collectedAt != $1.collectedAt ? $0.collectedAt > $1.collectedAt : $0.stampID < $1.stampID }
        func ordered(_ a: String, _ b: String) -> ComparisonResult { a.localizedCaseInsensitiveCompare(b) }
        switch sort {
        case .recentlyCollected:
            return stamps.sorted(by: byRecent)
        case .alphabetical:
            return stamps.sorted { let c = ordered(name($0), name($1)); return c != .orderedSame ? c == .orderedAscending : byRecent($0, $1) }
        case .country:
            return stamps.sorted {
                let c = ordered(country($0), country($1))
                if c != .orderedSame { return c == .orderedAscending }
                let n = ordered(name($0), name($1))
                return n != .orderedSame ? n == .orderedAscending : byRecent($0, $1)
            }
        case .collection:
            var firstOrder: [String: Int] = [:]
            for collection in catalog.collections.reversed() { for id in collection.destinationIDs { firstOrder[id] = collection.order } }
            return stamps.sorted {
                let a = firstOrder[$0.destinationID] ?? Int.max, b = firstOrder[$1.destinationID] ?? Int.max
                if a != b { return a < b }
                let n = ordered(name($0), name($1))
                return n != .orderedSame ? n == .orderedAscending : byRecent($0, $1)
            }
        case .verifiedFirst:
            return stamps.sorted { $0.isVerified != $1.isVerified ? $0.isVerified : byRecent($0, $1) }
        case .favoritesFirst:
            return stamps.sorted { $0.isFavorite != $1.isFavorite ? $0.isFavorite : byRecent($0, $1) }
        }
    }
}

nonisolated struct PassportSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let stamps: [CollectedStamp]
}

extension PassportGrouping {
    /// Splits stamps into labelled sections. Order within a section is preserved.
    nonisolated func sections(for stamps: [CollectedStamp], catalog: Catalog, tripTitle: (UUID) -> String?) -> [PassportSection] {
        switch self {
        case .none:
            return [PassportSection(id: "all", title: "", stamps: stamps)]
        case .region:
            return Region.allCases.compactMap { region in
                let items = stamps.filter { catalog.destination(id: $0.destinationID)?.region == region }
                return items.isEmpty ? nil : PassportSection(id: region.rawValue, title: region.title, stamps: items)
            } + other(stamps, catalog: catalog)
        case .country:
            let grouped = Dictionary(grouping: stamps, by: \.countryCode)
            return grouped.map { code, items in
                PassportSection(id: code, title: "\(CountryInfo.flag(for: code)) \(CountryInfo.name(for: code))", stamps: items)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .collection:
            var sections: [PassportSection] = []
            var placed = Set<String>()
            for collection in catalog.collections {
                let members = Set(collection.destinationIDs)
                let items = stamps.filter { members.contains($0.destinationID) }
                if !items.isEmpty { sections.append(PassportSection(id: collection.id, title: collection.title, stamps: items)) }
                placed.formUnion(items.map(\.stampID))
            }
            let rest = stamps.filter { !placed.contains($0.stampID) }
            if !rest.isEmpty { sections.append(PassportSection(id: "other", title: String(localized: "Other"), stamps: rest)) }
            return sections
        case .trip:
            let grouped = Dictionary(grouping: stamps) { $0.tripID }
            var sections: [PassportSection] = grouped.compactMap { key, items in
                guard let key, let title = tripTitle(key) else { return nil }
                return PassportSection(id: key.uuidString, title: title, stamps: items)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            let unassigned = stamps.filter { stamp in stamp.tripID.flatMap(tripTitle) == nil }
            if !unassigned.isEmpty { sections.append(PassportSection(id: "none", title: String(localized: "Not in a trip"), stamps: unassigned)) }
            return sections
        }
    }
}

private extension PassportGrouping {
    /// Stamps whose destination has left the catalogue still get a page.
    nonisolated func other(_ stamps: [CollectedStamp], catalog: Catalog) -> [PassportSection] {
        let orphans = stamps.filter { catalog.destination(id: $0.destinationID) == nil }
        return orphans.isEmpty ? [] : [PassportSection(id: "archived", title: String(localized: "Archived places"), stamps: orphans)]
    }
}

/// Filter criteria for Discover. `states` is evaluated against the passport.
nonisolated struct DestinationFilter: Equatable, Sendable {
    var categories: Set<DestinationCategory> = []
    var regions: Set<Region> = []
    var countryCodes: Set<String> = []
    var states: Set<StampState> = []
    var collectionID: String?

    var isActive: Bool { activeCount > 0 }

    var activeCount: Int {
        (categories.isEmpty ? 0 : 1) + (regions.isEmpty ? 0 : 1) + (countryCodes.isEmpty ? 0 : 1)
            + (states.isEmpty ? 0 : 1) + (collectionID == nil ? 0 : 1)
    }

    func matches(_ destination: Destination, state: StampState, catalog: Catalog) -> Bool {
        if !categories.isEmpty, !categories.contains(destination.category) { return false }
        if !regions.isEmpty, !regions.contains(destination.region) { return false }
        if !countryCodes.isEmpty, !countryCodes.contains(destination.countryCode) { return false }
        if !states.isEmpty, !states.contains(state) { return false }
        if let collectionID, !(catalog.collection(id: collectionID)?.destinationIDs.contains(destination.id) ?? false) { return false }
        return true
    }
}
