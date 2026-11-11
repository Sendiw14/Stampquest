import Foundation

/// Picks the "Near you" destination from one location fix. Pure: the view model decides when to read location.
nonisolated enum HomeNearbyFinder {
    /// Throttle between location reads for Home.
    static let minimumInterval: TimeInterval = 600
    static let maxFixAge: TimeInterval = 120

    /// Whether a fresh read is allowed: permission already granted (never prompted here) and not read in the last 10 minutes.
    static func mayRead(authorization: LocationAuthorization, servicesEnabled: Bool, lastRead: Date?, now: Date) -> Bool {
        authorization == .authorized && servicesEnabled && (lastRead.map { now.timeIntervalSince($0) >= minimumInterval } ?? true)
    }

    /// The nearest catalog destination whose own verification radius contains the fix. A stale or invalid fix gives nil.
    static func nearest(reading: LocationReading, catalog: Catalog, collectedIDs: Set<String>, now: Date) -> HomeNearby? {
        guard reading.horizontalAccuracy >= 0, now.timeIntervalSince(reading.timestamp) <= maxFixAge else { return nil }
        let inRange = catalog.destinations.compactMap { destination -> (Destination, Double)? in
            let distance = Geo.distanceMeters(lat1: reading.latitude, lon1: reading.longitude,
                                              lat2: destination.latitude, lon2: destination.longitude)
            return distance <= destination.verificationRadius ? (destination, distance) : nil
        }
        guard let best = inRange.min(by: { $0.1 < $1.1 }) else { return nil }
        return HomeNearby(destinationID: best.0.id, distanceMeters: best.1, isCollected: collectedIDs.contains(best.0.id))
    }
}
