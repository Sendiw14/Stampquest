import Foundation

nonisolated struct HomeMemory: Equatable, Sendable {
    let id: UUID
    let title: String
    let text: String
    let eventDate: Date
    let destinationID: String?
    let photoCount: Int
}

nonisolated struct HomeNearby: Equatable, Sendable {
    let destinationID: String
    let distanceMeters: Double
    let isCollected: Bool
}

nonisolated struct HomeSet: Equatable, Sendable {
    let progress: CollectionProgress
    /// Up to five collected destinations, most recent first.
    let shownIDs: [String]
    var extraCount: Int { max(0, progress.total - 5) }
}

/// Everything Home shows, derived from records. Built by `HomeSnapshotBuilder`; holds no counters of its own.
nonisolated struct HomeSnapshot: Equatable, Sendable {
    var isFirstRun: Bool
    var stampCount: Int
    var countryCount: Int
    var verifiedCount: Int
    var featuredID: String?
    var sideID: String?
    var pickIDs: [String]
    var sets: [HomeSet]
    var nearby: HomeNearby?
    var litCountryCodes: Set<String>
    var verifiedDestinationIDs: [String]
    var latestMemory: HomeMemory?
    var chip: HomeCopy.Chip?
    var greeting: HomeCopy.GreetingKind

    var showsAtlas: Bool { !isFirstRun && countryCount > 0 }
}

nonisolated enum HomeSnapshotBuilder {
    /// The catalog's first-run defaults: Paris first, then Kyoto, Santorini and Rome.
    static let firstRunDefaults = ["paris-eiffel-tower", "kyoto-fushimi-inari", "santorini-oia", "rome-colosseum"]

    static func build(catalog: Catalog, snapshot: PassportSnapshot, memory: HomeMemory?, nearby: HomeNearby?,
                      installID: String, now: Date, calendar: Calendar, dayOverride: String?) -> HomeSnapshot {
        let stamps = snapshot.stamps
        let isFirstRun = stamps.isEmpty
        let collected = Set(stamps.map(\.destinationID))
        func available(_ id: String) -> Bool { !collected.contains(id) && catalog.stamp(forDestination: id) != nil && catalog.destination(id: id) != nil }

        let sets = inProgressSets(catalog: catalog, snapshot: snapshot)
        var priority = snapshot.wishlist.sorted { $0.addedAt > $1.addedAt }.map(\.destinationID)
        priority += sets.compactMap { $0.progress.missingIDs.first }
        priority += catalog.featured.map(\.id)
        let rest = catalog.destinations.map(\.id)

        let firstRun = isFirstRun ? firstRunDefaults.filter(available) : nil
        let seed = HomeFeaturedPicker.seed(installID: installID, day: HomeFeaturedPicker.dayNumber(now, calendar: calendar))
        var picks = HomeFeaturedPicker.picks(priority: priority.filter(available), rest: rest.filter(available),
                                             firstRun: (firstRun?.count ?? 0) >= 2 ? firstRun : nil, seed: seed)
        if let override = dayOverride, available(override), override != picks.featured {
            let previous = picks.featured
            picks.featured = override
            picks.side = previous
            picks.picks.removeAll { $0 == override }
        }

        let verified = stamps.filter(\.isVerified)
        return HomeSnapshot(
            isFirstRun: isFirstRun, stampCount: stamps.count, countryCount: HomeCopy.countryCount(stamps),
            verifiedCount: verified.count, featuredID: picks.featured, sideID: picks.side, pickIDs: picks.picks,
            sets: sets, nearby: isFirstRun ? nil : nearby, litCountryCodes: Set(stamps.map(\.countryCode)),
            verifiedDestinationIDs: verified.map(\.destinationID), latestMemory: isFirstRun ? nil : memory,
            chip: HomeCopy.chip(isFirstRun: isFirstRun, catalogCount: catalog.destinations.count, verifiedCount: verified.count,
                                firstStampDate: stamps.map(\.collectedAt).min()),
            greeting: HomeCopy.greetingKind(hour: calendar.component(.hour, from: now), isFirstRun: isFirstRun))
    }

    /// At most two sets with at least one stamp and not complete: latest activity first, then closest to done.
    static func inProgressSets(catalog: Catalog, snapshot: PassportSnapshot) -> [HomeSet] {
        let all = CollectionProgress.all(catalog: catalog, snapshot: snapshot).filter { !$0.isComplete && $0.collected > 0 }
        func latest(_ progress: CollectionProgress) -> Date {
            progress.collectedIDs.compactMap { snapshot.collectedStamp(forDestination: $0)?.collectedAt }.max() ?? .distantPast
        }
        let sorted = all.sorted { latest($0) != latest($1) ? latest($0) > latest($1) : $0.fraction > $1.fraction }
        return sorted.prefix(2).map { progress in
            let recent = progress.collectedIDs
                .sorted { (snapshot.collectedStamp(forDestination: $0)?.collectedAt ?? .distantPast) > (snapshot.collectedStamp(forDestination: $1)?.collectedAt ?? .distantPast) }
            return HomeSet(progress: progress, shownIDs: Array(recent.prefix(5)))
        }
    }
}
