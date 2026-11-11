import Foundation

/// A milestone derived entirely from the user's records.
///
/// Achievements are *computed*, not stored, so they can never be awarded twice,
/// never drift from the data, and are naturally revoked if the underlying record
/// is removed. The unlock date is the date the qualifying record was created.
nonisolated struct Achievement: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case firstStamp, firstVerifiedVisit, fiveDestinations, tenDestinations, threeCountries
        case threeRegions, firstCollection, firstMemory, firstTrip
    }

    let kind: Kind
    let title: String
    let detail: String
    let symbolName: String
    let current: Int
    let target: Int
    let unlockedAt: Date?

    var id: String { kind.rawValue }
    var isUnlocked: Bool { unlockedAt != nil }
    var fraction: Double { target == 0 ? 0 : min(1, Double(current) / Double(target)) }
}

nonisolated enum AchievementEvaluator {
    static func evaluate(snapshot: PassportSnapshot, catalog: Catalog) -> [Achievement] {
        let byDate = snapshot.stamps.sorted { $0.collectedAt < $1.collectedAt }
        let stats = PassportStatistics.compute(from: snapshot, catalog: catalog)

        func nth(_ n: Int) -> Date? { byDate.count >= n ? byDate[n - 1].collectedAt : nil }

        let verifiedDates = snapshot.stamps.compactMap(\.verifiedAt).sorted()

        // Date the Nth distinct country / region was first reached.
        func distinctReached(_ n: Int, key: (CollectedStamp) -> String?) -> Date? {
            var seen = Set<String>()
            for stamp in byDate {
                if let k = key(stamp) { seen.insert(k) }
                if seen.count >= n { return stamp.collectedAt }
            }
            return nil
        }

        let completedDates = CollectionProgress.all(catalog: catalog, snapshot: snapshot).compactMap(\.completedAt).sorted()

        return [
            Achievement(kind: .firstStamp, title: String(localized: "First Stamp"),
                        detail: String(localized: "Collect your first stamp."), symbolName: "checkmark.seal",
                        current: min(stats.collectedStamps, 1), target: 1, unlockedAt: nth(1)),
            Achievement(kind: .firstVerifiedVisit, title: String(localized: "First Verified Visit"),
                        detail: String(localized: "Verify a visit while you are there."), symbolName: "location.circle",
                        current: min(stats.verifiedVisits, 1), target: 1, unlockedAt: verifiedDates.first),
            Achievement(kind: .fiveDestinations, title: String(localized: "Five Destinations"),
                        detail: String(localized: "Collect five different stamps."), symbolName: "5.circle",
                        current: min(stats.destinationsCollected, 5), target: 5, unlockedAt: nth(5)),
            Achievement(kind: .tenDestinations, title: String(localized: "Ten Destinations"),
                        detail: String(localized: "Collect ten different stamps."), symbolName: "10.circle",
                        current: min(stats.destinationsCollected, 10), target: 10, unlockedAt: nth(10)),
            Achievement(kind: .threeCountries, title: String(localized: "Three Countries"),
                        detail: String(localized: "Collect stamps from three countries."), symbolName: "flag",
                        current: min(stats.countriesCollected, 3), target: 3,
                        unlockedAt: distinctReached(3) { $0.countryCode }),
            Achievement(kind: .threeRegions, title: String(localized: "Three Regions"),
                        detail: String(localized: "Explore three world regions."), symbolName: "globe",
                        current: min(stats.regionsExplored, 3), target: 3,
                        unlockedAt: distinctReached(3) { catalog.destination(id: $0.destinationID)?.region.rawValue }),
            Achievement(kind: .firstCollection, title: String(localized: "First Collection Completed"),
                        detail: String(localized: "Complete every stamp in a collection."), symbolName: "rosette",
                        current: min(stats.completedCollections, 1), target: 1, unlockedAt: completedDates.first),
            Achievement(kind: .firstMemory, title: String(localized: "First Memory"),
                        detail: String(localized: "Write down a memory."), symbolName: "book",
                        current: min(stats.memories, 1), target: 1, unlockedAt: snapshot.memoryCount > 0 ? snapshot.firstMemoryDate : nil),
            Achievement(kind: .firstTrip, title: String(localized: "First Trip"),
                        detail: String(localized: "Create a trip."), symbolName: "suitcase",
                        current: min(stats.trips, 1), target: 1, unlockedAt: snapshot.tripCount > 0 ? snapshot.firstTripDate : nil),
        ]
    }
}
