import Foundation

/// The filters of the Discover Filters sheet (D6): AND across groups, OR within a group. Never persisted.
nonisolated struct DiscoverFilter: Hashable, Sendable {
    enum Show: String, CaseIterable, Hashable, Sendable {
        case all, toCollect, collected, wishlist

        var title: String {
            switch self {
            case .all: String(localized: "All")
            case .toCollect: String(localized: "To collect")
            case .collected: String(localized: "Collected")
            case .wishlist: String(localized: "Wishlist")
            }
        }
    }

    /// One removable chip of the Results list.
    enum Chip: Hashable, Sendable {
        case category(DestinationCategory), region(Region), country(String), show(Show)

        var id: String {
            switch self {
            case .category(let c): "category-\(c.rawValue)"
            case .region(let r): "region-\(r.rawValue)"
            case .country(let code): "country-\(code)"
            case .show(let s): "show-\(s.rawValue)"
            }
        }

        var title: String {
            switch self {
            case .category(let c): c.title
            case .region(let r): r.title
            case .country(let code): CountryInfo.name(for: code)
            case .show(let s): s.title
            }
        }
    }

    var categories: Set<DestinationCategory> = []
    var regions: Set<Region> = []
    var countryCodes: Set<String> = []
    var show: Show = .all

    var isActive: Bool { !categories.isEmpty || !regions.isEmpty || !countryCodes.isEmpty || show != .all }

    /// "Showing N places" never depends on this; it is only the number of chips.
    var activeCount: Int { categories.count + regions.count + countryCodes.count + (show == .all ? 0 : 1) }

    func matches(_ destination: Destination, state: StampState) -> Bool {
        if !categories.isEmpty, !categories.contains(destination.category) { return false }
        if !regions.isEmpty, !regions.contains(destination.region) { return false }
        if !countryCodes.isEmpty, !countryCodes.contains(destination.countryCode) { return false }
        switch show {
        case .all: return true
        case .toCollect: return !state.isInPassport
        case .collected: return state.isInPassport
        case .wishlist: return state == .wishlisted
        }
    }

    /// Chips in a fixed order: interests, regions, countries (alphabetical), then Show.
    var chips: [Chip] {
        categories.sorted { $0.title < $1.title }.map(Chip.category)
            + regions.sorted { $0.title < $1.title }.map(Chip.region)
            + countryCodes.sorted { CountryInfo.name(for: $0) < CountryInfo.name(for: $1) }.map(Chip.country)
            + (show == .all ? [] : [Chip.show(show)])
    }

    mutating func remove(_ chip: Chip) {
        switch chip {
        case .category(let c): categories.remove(c)
        case .region(let r): regions.remove(r)
        case .country(let code): countryCodes.remove(code)
        case .show: show = .all
        }
    }

    mutating func toggle(_ category: DestinationCategory) { if !categories.insert(category).inserted { categories.remove(category) } }
    mutating func toggle(_ region: Region) { if !regions.insert(region).inserted { regions.remove(region) } }
    mutating func toggle(country code: String) { if !countryCodes.insert(code).inserted { countryCodes.remove(code) } }
}

/// What a Results list is about: its title and, inside a collection, its order.
nonisolated struct DiscoverResultsSpec: Hashable, Sendable {
    enum Scope: Hashable, Sendable { case places, category(DestinationCategory), collection(String) }

    var scope: Scope
    var filter: DiscoverFilter

    static func category(_ category: DestinationCategory) -> DiscoverResultsSpec {
        DiscoverResultsSpec(scope: .category(category), filter: DiscoverFilter(categories: [category]))
    }
}

nonisolated enum DiscoverResults {
    /// Matches for `filter` inside `scope`: A to Z by name, or collection order inside a collection. There is no
    /// popularity sort. `state` supplies the passport state of a destination.
    static func matches(scope: DiscoverResultsSpec.Scope, filter: DiscoverFilter, catalog: Catalog,
                        state: (String) -> StampState) -> [Destination] {
        let base: [Destination]
        switch scope {
        case .collection(let id):
            base = catalog.collection(id: id)?.destinationIDs.compactMap(catalog.destination(id:)) ?? []
            return base.filter { filter.matches($0, state: state($0.id)) }
        case .places, .category:
            base = catalog.destinations
            return base.filter { filter.matches($0, state: state($0.id)) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    static func count(filter: DiscoverFilter, catalog: Catalog, state: (String) -> StampState) -> Int {
        catalog.destinations.reduce(0) { $0 + (filter.matches($1, state: state($1.id)) ? 1 : 0) }
    }
}
