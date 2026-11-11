import Testing
import Foundation
import SwiftData
@testable import StampQuest

@MainActor
struct PassportStoreTests {
    let container: ModelContainer
    let store: PassportStore
    let photos = RecordingPhotoDeleter()

    init() throws {
        container = try Fixture.container()
        let clock = TickingClock()
        store = PassportStore(context: container.mainContext, catalog: Fixture.catalog, photoFiles: photos, now: { clock() })
    }

    private var stampCount: Int { (try? container.mainContext.fetchCount(FetchDescriptor<UserStamp>())) ?? -1 }

    // MARK: Collecting

    @Test func manualCollectionCreatesExactlyOneUnverifiedRecord() throws {
        let outcome = try store.collect(destinationID: "a")
        #expect(outcome.isNew)
        #expect(stampCount == 1)
        #expect(outcome.stamp.state == .collected)
        #expect(outcome.stamp.method == .manual)
        #expect(outcome.stamp.verification == nil)
    }

    @Test func collectingTwiceIsIdempotent() throws {
        let first = try store.collect(destinationID: "a")
        let firstDate = first.stamp.collectedAt
        let second = try store.collect(destinationID: "a")
        #expect(!second.isNew)
        #expect(stampCount == 1)
        #expect(second.stamp.collectedAt == firstDate, "A repeat must not rewrite the collection date")
    }

    @Test func collectingUnknownDestinationThrowsAndStoresNothing() {
        #expect(throws: PassportError.unknownDestination("nope")) { try store.collect(destinationID: "nope") }
        #expect(stampCount == 0)
    }

    // MARK: Wishlist vs collection

    @Test func wishlistIsNotACollectedStamp() throws {
        #expect(try store.addToWishlist(destinationID: "a"))
        #expect(store.state(of: "a") == .wishlisted)
        let snapshot = store.snapshot()
        let stats = PassportStatistics.compute(from: snapshot, catalog: Fixture.catalog)
        #expect(stats.collectedStamps == 0)
        #expect(stats.destinationsCollected == 0)
        #expect(stats.countriesCollected == 0)
        #expect(stats.wishlistCount == 1)
    }

    @Test func collectingClearsTheWishlistEntry() throws {
        try store.addToWishlist(destinationID: "a")
        try store.collect(destinationID: "a")
        #expect(!store.isWishlisted("a"))
        #expect(store.state(of: "a") == .collected)
        #expect(store.snapshot().wishlist.isEmpty)
    }

    @Test func collectedDestinationCannotBeWishlisted() throws {
        try store.collect(destinationID: "a")
        #expect(try store.addToWishlist(destinationID: "a") == false)
        #expect(!store.isWishlisted("a"))
    }

    @Test func addingToWishlistTwiceKeepsOneEntry() throws {
        #expect(try store.addToWishlist(destinationID: "b"))
        #expect(try store.addToWishlist(destinationID: "b") == false)
        #expect(store.snapshot().wishlist.count == 1)
        #expect(try store.removeFromWishlist(destinationID: "b"))
        #expect(try store.removeFromWishlist(destinationID: "b") == false)
    }

    // MARK: Verification

    @Test func verifyingExistingManualStampUpgradesInPlace() throws {
        let manual = try store.collect(destinationID: "a").stamp
        let originalDate = manual.collectedAt
        let outcome = try store.recordVerification(destinationID: "a", verification: Fixture.verification())
        guard case .upgraded(let stamp) = outcome else { Issue.record("expected upgrade"); return }
        #expect(stampCount == 1, "Verification must not create a duplicate")
        #expect(stamp.state == .verified)
        #expect(stamp.method == .manual, "Original collection method is history and stays truthful")
        #expect(stamp.collectedAt == originalDate)
    }

    @Test func verifyingWithoutAStampCollectsAndVerifies() throws {
        let outcome = try store.recordVerification(destinationID: "c", verification: Fixture.verification())
        guard case .collectedAndVerified(let stamp) = outcome else { Issue.record("expected new verified stamp"); return }
        #expect(stamp.method == .verified)
        #expect(stamp.isVerified)
        #expect(stampCount == 1)
    }

    @Test func verifyingTwiceDoesNotOverwriteTheFirstVerification() throws {
        let first = Fixture.verification(at: Date(timeIntervalSince1970: 1_800_000_000))
        try store.recordVerification(destinationID: "a", verification: first)
        let outcome = try store.recordVerification(destinationID: "a", verification: Fixture.verification(at: Date(timeIntervalSince1970: 1_900_000_000)))
        guard case .alreadyVerified(let stamp) = outcome else { Issue.record("expected alreadyVerified"); return }
        #expect(stamp.verification?.id == first.id)
        #expect(stampCount == 1)
    }

    @Test func manualCollectionIsNeverCountedAsAVerifiedVisit() throws {
        try store.collect(destinationID: "a")
        try store.collect(destinationID: "b")
        let stats = PassportStatistics.compute(from: store.snapshot(), catalog: Fixture.catalog)
        #expect(stats.collectedStamps == 2)
        #expect(stats.verifiedVisits == 0)
    }

    // MARK: Removal and undo

    @Test func removingAStampUpdatesStatisticsAndProgress() throws {
        try store.collect(destinationID: "a")
        try store.collect(destinationID: "b")
        let before = PassportStatistics.compute(from: store.snapshot(), catalog: Fixture.catalog)
        #expect(before.completedCollections == 1)

        let backup = try store.removeStamp(destinationID: "b")
        #expect(backup != nil)
        let after = PassportStatistics.compute(from: store.snapshot(), catalog: Fixture.catalog)
        #expect(after.collectedStamps == 1)
        #expect(after.completedCollections == 0)
        #expect(try store.removeStamp(destinationID: "b") == nil, "Removing twice is harmless")
    }

    @Test func undoRestoresTheStampExactly() throws {
        try store.collect(destinationID: "a")
        try store.recordVerification(destinationID: "a", verification: Fixture.verification())
        try store.setFavorite(destinationID: "a", true)
        let original = store.stamp(forDestination: "a")!
        let (date, vid) = (original.collectedAt, original.verification?.id)

        let backup = try #require(try store.removeStamp(destinationID: "a"))
        try store.restoreStamp(backup)
        try store.restoreStamp(backup) // restoring twice must not duplicate

        let restored = try #require(store.stamp(forDestination: "a"))
        #expect(stampCount == 1)
        #expect(restored.collectedAt == date)
        #expect(restored.verification?.id == vid)
        #expect(restored.isFavorite)
    }

    // MARK: Memories

    @Test func deletingAMemoryNeverDeletesStamps() throws {
        try store.collect(destinationID: "a")
        let memory = try store.saveMemory(MemoryDraft(title: "Sunset", text: "Lovely.", destinationID: "a", photoFilenames: ["p1.jpg"]))
        try store.deleteMemory(memory)
        #expect(stampCount == 1)
        #expect(store.stamp(forDestination: "a") != nil)
        #expect(photos.deleted == ["p1.jpg"], "The memory's photo files are cleaned up")
    }

    @Test func memoryNeedsSomeContent() {
        #expect(throws: PassportError.self) { try store.saveMemory(MemoryDraft(title: "  ", text: "")) }
    }

    @Test func editingAMemoryPersistsAndRemovesDroppedPhotos() throws {
        let memory = try store.saveMemory(MemoryDraft(title: "One", text: "t", tags: ["Food", " food ", "views"], photoFilenames: ["a.jpg", "b.jpg"]))
        #expect(memory.tags == ["food", "views"], "Tags are normalised and de-duplicated")
        var draft = MemoryDraft(title: "Two", text: "t2", photoFilenames: ["a.jpg"])
        draft.destinationID = "c"
        try store.saveMemory(draft, replacing: memory)
        #expect(memory.title == "Two")
        #expect(memory.destinationID == "c")
        #expect(photos.deleted == ["b.jpg"])
        #expect((try? container.mainContext.fetchCount(FetchDescriptor<MemoryEntry>())) == 1)
    }

    @Test func memoryCannotReferenceAnUnknownDestination() {
        #expect(throws: PassportError.unknownDestination("ghost")) {
            try store.saveMemory(MemoryDraft(title: "x", destinationID: "ghost"))
        }
    }

    @Test func removingAStampKeepsMemoriesAboutThatPlace() throws {
        try store.collect(destinationID: "a")
        try store.saveMemory(MemoryDraft(title: "Trip day", destinationID: "a"))
        try store.removeStamp(destinationID: "a")
        #expect((try? container.mainContext.fetchCount(FetchDescriptor<MemoryEntry>())) == 1)
    }

    // MARK: Trips

    @Test func deletingATripDetachesStampsAndMemoriesWithoutDeletingThem() throws {
        let trip = try store.saveTrip(TripDraft(title: "Europe", destinationIDs: ["a", "b"]))
        try store.collect(destinationID: "a")
        try store.setTrip(destinationID: "a", tripID: trip.id)
        let memory = try store.saveMemory(MemoryDraft(title: "Day 1", tripID: trip.id))

        try store.deleteTrip(trip)
        #expect((try? container.mainContext.fetchCount(FetchDescriptor<Trip>())) == 0)
        #expect(store.stamp(forDestination: "a")?.tripID == nil)
        #expect(stampCount == 1)
        #expect(memory.tripID == nil)
        #expect((try? container.mainContext.fetchCount(FetchDescriptor<MemoryEntry>())) == 1)
    }

    @Test func tripValidationRejectsBlankTitlesAndBackwardsDates() {
        let start = Date(timeIntervalSince1970: 2_000_000), end = Date(timeIntervalSince1970: 1_000_000)
        #expect(throws: PassportError.self) { try store.saveTrip(TripDraft(title: "   ")) }
        #expect(throws: PassportError.self) { try store.saveTrip(TripDraft(title: "Backwards", startDate: start, endDate: end)) }
        #expect(throws: Never.self) { try store.saveTrip(TripDraft(title: "Open ended", startDate: start, endDate: nil)) }
    }

    // MARK: Data management

    @Test func deleteAllDataRemovesEveryUserRecordButNotTheCatalog() throws {
        try store.collect(destinationID: "a")
        try store.addToWishlist(destinationID: "b")
        try store.saveMemory(MemoryDraft(title: "m", photoFilenames: ["z.jpg"]))
        try store.saveTrip(TripDraft(title: "t"))
        try store.deleteAllData()
        let snapshot = store.snapshot()
        #expect(snapshot.stamps.isEmpty && snapshot.wishlist.isEmpty && snapshot.memoryCount == 0 && snapshot.tripCount == 0)
        #expect(photos.deleted == ["z.jpg"])
        #expect(Fixture.catalog.destinations.count == 6)
    }
}

@MainActor
struct PersistenceReopenTests {
    @Test func recordsSurviveReopeningTheStore() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sq-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Passport.store")

        do {
            let container = try PersistenceController.makeContainer(url: url)
            let store = PassportStore(context: container.mainContext, catalog: Fixture.catalog)
            try store.collect(destinationID: "a")
            try store.recordVerification(destinationID: "a", verification: Fixture.verification())
            try store.addToWishlist(destinationID: "b")
            try store.saveMemory(MemoryDraft(title: "Kept", destinationID: "a"))
        }

        let reopened = try PersistenceController.makeContainer(url: url)
        let store = PassportStore(context: reopened.mainContext, catalog: Fixture.catalog)
        let snapshot = store.snapshot()
        #expect(snapshot.stamps.count == 1)
        #expect(snapshot.stamps.first?.isVerified == true)
        #expect(snapshot.wishlist.count == 1)
        #expect(snapshot.memoryCount == 1)
        let stored = try #require(store.stamp(forDestination: "a"))
        #expect(stored.verification?.distanceMeters == 42, "The Codable verification value round-trips")
    }

    @Test func movingAStoreToBackupPreservesItsFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sq-backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Passport.store")
        _ = try PersistenceController.makeContainer(url: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        let backup = try PersistenceController.moveStoreToBackup(url: url, backupsRoot: dir.appendingPathComponent("Backups"))
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(FileManager.default.fileExists(atPath: backup.appendingPathComponent("Passport.store").path))
    }
}
