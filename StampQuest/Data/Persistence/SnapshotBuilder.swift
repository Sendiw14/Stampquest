import Foundation

extension PassportSnapshot {
    /// Builds a snapshot from SwiftData models (typically the results of `@Query`).
    @MainActor
    init(userStamps: [UserStamp], wishlist: [WishlistItem], memories: [MemoryEntry], trips: [Trip]) {
        self.init(
            stamps: userStamps.map {
                CollectedStamp(stampID: $0.stampID, destinationID: $0.destinationID,
                               countryCode: $0.countryCodeSnapshot, title: $0.titleSnapshot,
                               collectedAt: $0.collectedAt, verifiedAt: $0.verification?.verifiedAt,
                               isFavorite: $0.isFavorite, tripID: $0.tripID)
            },
            wishlist: wishlist.map { WishlistEntry(destinationID: $0.destinationID, addedAt: $0.addedAt) },
            memoryCount: memories.count,
            tripCount: trips.count,
            firstMemoryDate: memories.map(\.createdAt).min(),
            firstTripDate: trips.map(\.createdAt).min())
    }
}
