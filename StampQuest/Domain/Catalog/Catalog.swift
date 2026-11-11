import Foundation

/// A problem found while loading catalog data. Records with errors are dropped;
/// the rest of the catalog still loads.
nonisolated struct CatalogIssue: Error, Hashable, Sendable {
    let recordID: String
    let message: String
}

/// The bundled, versioned catalogue of destinations, stamps and collections.
///
/// The catalogue is immutable after loading. User-owned records (collected
/// stamps, wishlist, memories) reference it by stable identifier and never copy
/// its content, so a catalogue update can never corrupt a passport.
nonisolated struct Catalog: Sendable {
    let version: String
    let destinations: [Destination]
    let stamps: [StampDesign]
    let collections: [StampCollection]
    let issues: [CatalogIssue]

    private let destinationIndex: [String: Destination]
    private let stampByDestination: [String: StampDesign]
    private let collectionIndex: [String: StampCollection]
    private let searchIndex: [CatalogSearch.Entry]

    init(version: String, destinations: [Destination], stamps: [StampDesign],
         collections: [StampCollection], issues: [CatalogIssue] = []) {
        self.version = version
        self.destinations = destinations
        self.stamps = stamps
        self.collections = collections.sorted { $0.order < $1.order }
        self.issues = issues
        self.destinationIndex = Dictionary(uniqueKeysWithValues: destinations.map { ($0.id, $0) })
        self.stampByDestination = Dictionary(uniqueKeysWithValues: stamps.map { ($0.destinationID, $0) })
        self.collectionIndex = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0) })
        self.searchIndex = destinations.map(CatalogSearch.Entry.init)
    }

    static let empty = Catalog(version: "0", destinations: [], stamps: [], collections: [])

    // MARK: Lookup

    func destination(id: String) -> Destination? { destinationIndex[id] }
    func stamp(forDestination id: String) -> StampDesign? { stampByDestination[id] }
    func stamp(id stampID: String) -> StampDesign? {
        StampID.destinationID(from: stampID).flatMap { stampByDestination[$0] }
    }
    func collection(id: String) -> StampCollection? { collectionIndex[id] }

    func collections(containing destinationID: String) -> [StampCollection] {
        collections.filter { $0.destinationIDs.contains(destinationID) }
    }

    // MARK: Derived

    var featured: [Destination] { destinations.filter(\.isFeatured) }

    var countries: [Country] {
        let grouped = Dictionary(grouping: destinations, by: \.countryCode)
        return grouped.map { code, items in
            Country(code: code, name: CountryInfo.name(for: code), region: items[0].region,
                    destinationIDs: items.map(\.id))
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func countryCode(forDestination id: String) -> String? { destinationIndex[id]?.countryCode }

    /// Other places worth looking at next to `destination`: same collections first,
    /// then same category or region. Deterministic.
    func related(to destination: Destination, limit: Int = 6) -> [Destination] {
        var scored: [(Destination, Int)] = []
        let myCollections = Set(collections(containing: destination.id).map(\.id))
        for other in destinations where other.id != destination.id {
            var score = 0
            let shared = Set(collections(containing: other.id).map(\.id)).intersection(myCollections).count
            score += shared * 10
            if other.category == destination.category { score += 4 }
            if other.region == destination.region { score += 2 }
            if other.countryCode == destination.countryCode { score += 1 }
            if score > 0 { scored.append((other, score)) }
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name < $1.0.name }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: Search

    /// Ranked search across names, landmarks, countries, regions, categories and
    /// keywords. Case- and diacritic-insensitive. Empty query returns everything.
    func search(_ query: String) -> [Destination] {
        CatalogSearch.search(query, in: searchIndex, destinations: destinationIndex)
    }
}
