import Foundation

/// An immutable, value-type view of the user's records.
///
/// Every statistic, progress figure and achievement is computed from a snapshot,
/// never from independently maintained counters, so numbers cannot drift from the
/// truth. Snapshots are cheap to build and trivial to construct in tests.
nonisolated struct CollectedStamp: Hashable, Identifiable, Sendable {
    var id: String { stampID }
    let stampID: String
    let destinationID: String
    let countryCode: String
    let title: String
    let collectedAt: Date
    let verifiedAt: Date?
    let isFavorite: Bool
    let tripID: UUID?

    var isVerified: Bool { verifiedAt != nil }

    init(stampID: String, destinationID: String, countryCode: String, title: String, collectedAt: Date,
         verifiedAt: Date? = nil, isFavorite: Bool = false, tripID: UUID? = nil) {
        self.stampID = stampID
        self.destinationID = destinationID
        self.countryCode = countryCode
        self.title = title
        self.collectedAt = collectedAt
        self.verifiedAt = verifiedAt
        self.isFavorite = isFavorite
        self.tripID = tripID
    }
}

nonisolated struct WishlistEntry: Hashable, Identifiable, Sendable {
    var id: String { destinationID }
    let destinationID: String
    let addedAt: Date
}

nonisolated struct PassportSnapshot: Sendable {
    let stamps: [CollectedStamp]
    let wishlist: [WishlistEntry]
    let memoryCount: Int
    let tripCount: Int
    let firstMemoryDate: Date?
    let firstTripDate: Date?

    private let stampByDestination: [String: CollectedStamp]
    private let wishlistIDs: Set<String>

    init(stamps: [CollectedStamp], wishlist: [WishlistEntry] = [], memoryCount: Int = 0, tripCount: Int = 0,
         firstMemoryDate: Date? = nil, firstTripDate: Date? = nil) {
        // Defensive: if two records somehow share a destination keep the earliest.
        var byDestination: [String: CollectedStamp] = [:]
        for stamp in stamps.sorted(by: { $0.collectedAt < $1.collectedAt }) where byDestination[stamp.destinationID] == nil {
            byDestination[stamp.destinationID] = stamp
        }
        self.stampByDestination = byDestination
        self.stamps = byDestination.values.sorted { $0.collectedAt > $1.collectedAt }
        self.wishlist = wishlist
        self.wishlistIDs = Set(wishlist.map(\.destinationID))
        self.memoryCount = memoryCount
        self.tripCount = tripCount
        self.firstMemoryDate = firstMemoryDate
        self.firstTripDate = firstTripDate
    }

    static let empty = PassportSnapshot(stamps: [])

    func collectedStamp(forDestination id: String) -> CollectedStamp? { stampByDestination[id] }
    func isWishlisted(_ destinationID: String) -> Bool { wishlistIDs.contains(destinationID) }

    /// The one state that applies to a destination. A collected stamp always wins over
    /// a lingering wishlist entry.
    func state(of destinationID: String) -> StampState {
        if let stamp = stampByDestination[destinationID] { return stamp.isVerified ? .verified : .collected }
        return wishlistIDs.contains(destinationID) ? .wishlisted : .notCollected
    }
}

nonisolated struct PassportStatistics: Equatable, Sendable {
    /// Unique stamp records in the passport.
    let collectedStamps: Int
    /// Unique destinations whose stamp carries a successful location verification.
    let verifiedVisits: Int
    /// Unique countries represented by collected stamps.
    let countriesCollected: Int
    /// Unique destinations collected (equal to stamps while each destination has one stamp).
    let destinationsCollected: Int
    /// Places saved for later. Never counted as collected or visited.
    let wishlistCount: Int
    let completedCollections: Int
    let regionsExplored: Int
    let memories: Int
    let trips: Int

    static func compute(from snapshot: PassportSnapshot, catalog: Catalog) -> PassportStatistics {
        let collectedIDs = Set(snapshot.stamps.map(\.destinationID))
        let countries = Set(snapshot.stamps.map(\.countryCode))
        let regions = Set(snapshot.stamps.compactMap { catalog.destination(id: $0.destinationID)?.region })
        let completed = catalog.collections.filter { CollectionProgress.make(for: $0, snapshot: snapshot).isComplete }.count
        return PassportStatistics(
            collectedStamps: snapshot.stamps.count,
            verifiedVisits: snapshot.stamps.filter(\.isVerified).count,
            countriesCollected: countries.count,
            destinationsCollected: collectedIDs.count,
            wishlistCount: snapshot.wishlist.filter { !collectedIDs.contains($0.destinationID) }.count,
            completedCollections: completed,
            regionsExplored: regions.count,
            memories: snapshot.memoryCount,
            trips: snapshot.tripCount)
    }
}

/// How far through a collection the person is, derived from records and the
/// catalogue's current membership list.
nonisolated struct CollectionProgress: Identifiable, Equatable, Sendable {
    var id: String { collection.id }
    let collection: StampCollection
    let collectedIDs: [String]
    let missingIDs: [String]
    /// The date the last missing stamp was collected, if the collection is complete.
    let completedAt: Date?

    var total: Int { collection.destinationIDs.count }
    var collected: Int { collectedIDs.count }
    var isComplete: Bool { total > 0 && missingIDs.isEmpty }
    var fraction: Double { total == 0 ? 0 : Double(collected) / Double(total) }

    static func make(for collection: StampCollection, snapshot: PassportSnapshot) -> CollectionProgress {
        var collected: [String] = []
        var missing: [String] = []
        var latest: Date?
        for id in collection.destinationIDs {
            if let stamp = snapshot.collectedStamp(forDestination: id) {
                collected.append(id)
                latest = max(latest ?? stamp.collectedAt, stamp.collectedAt)
            } else {
                missing.append(id)
            }
        }
        return CollectionProgress(collection: collection, collectedIDs: collected, missingIDs: missing,
                                  completedAt: missing.isEmpty && !collected.isEmpty ? latest : nil)
    }

    static func all(catalog: Catalog, snapshot: PassportSnapshot) -> [CollectionProgress] {
        catalog.collections.map { make(for: $0, snapshot: snapshot) }
    }
}
