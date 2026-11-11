import Testing
import Foundation
import SwiftData
@testable import StampQuest

struct StampDetailStateTests {
    @Test func everyLegalTransitionAndNoOthers() {
        typealias S = StampDetailState
        let all: [S] = [.notCollected, .wishlisted, .collectedManual, .collectedVerified]
        let legal: Set<[S]> = [[.notCollected, .wishlisted], [.wishlisted, .notCollected], [.notCollected, .collectedManual], [.wishlisted, .collectedManual],
                               [.collectedManual, .collectedVerified], [.collectedManual, .notCollected], [.collectedVerified, .notCollected]]
        for from in all { for to in all {
            #expect(from.canMove(to: to) == legal.contains([from, to]), "\(from) to \(to)")
        } }
        #expect(!S.collectedVerified.canMove(to: .collectedManual), "A verified stamp never goes back to by hand")
        #expect(!S.collectedVerified.canMove(to: .wishlisted))
    }

    @Test func theStateComesFromTheStampStateAndOnlyVerifiedIsVerified() {
        #expect(StampDetailState(.notCollected) == .notCollected && StampDetailState(.wishlisted) == .wishlisted)
        #expect(StampDetailState(.collected) == .collectedManual && !StampDetailState(.collected).isVerified)
        #expect(StampDetailState(.verified).isVerified && StampDetailState(.verified).isCollected)
        #expect(!StampDetailState.wishlisted.isCollected, "A wishlist is not a collection")
    }
}

@MainActor
struct StampDetailRecordsTests {
    let env: AppEnvironment
    let catalog = DiscoverFixture.world

    init() throws {
        env = AppEnvironment(catalog: DiscoverFixture.world, container: try Fixture.container(),
                             preferences: PreferencesStore(defaults: UserDefaults(suiteName: "stamp-detail-\(UUID().uuidString)")!),
                             locationProvider: MockLocationProvider(), photos: PhotoStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("sd-\(UUID().uuidString)")))
    }

    private func model(_ id: String, collector: StampDetailViewModel.Collector? = nil, remover: StampDetailViewModel.Remover? = nil) -> StampDetailViewModel {
        StampDetailViewModel(env: env, destinationID: id, collector: collector, remover: remover)
    }

    private var stampCount: Int { (try? env.container.mainContext.fetchCount(FetchDescriptor<UserStamp>())) ?? -1 }

    // MARK: Collect

    @Test func collectingWritesOneUnverifiedRecordAndRevealsOnlyAfterTheSave() async throws {
        let m = model("kyoto")
        #expect(m.reveal == nil)
        await m.collect()
        #expect(stampCount == 1 && m.reveal?.destinationID == "kyoto" && m.reveal?.isVerified == false)
        let stamp = try #require(env.store.stamp(forDestination: "kyoto"))
        #expect(stamp.method == .manual && stamp.verification == nil, "Collecting by hand is never verified")
        #expect(!m.isWorking && m.failure == nil)
    }

    @Test func collectingAWishlistedStampRemovesItsWishlistEntryInTheSameStep() async throws {
        try env.store.addToWishlist(destinationID: "kyoto")
        await model("kyoto").collect()
        #expect(env.store.state(of: "kyoto") == .collected)
        #expect(try env.container.mainContext.fetchCount(FetchDescriptor<WishlistItem>()) == 0, "The stamp is never both collected and wishlisted")
    }

    @Test func aDoubleTapAndAStaleScreenCreateOneRecordAndReplayNothing() async throws {
        let first = model("kyoto"), stale = model("kyoto")
        await first.collect()
        await stale.collect()   // the second screen still showed "Collect stamp"
        #expect(stampCount == 1)
        #expect(first.reveal != nil && stale.reveal == nil, "An already collected stamp resolves to success without a second reveal")
    }

    @Test func aFailedCollectLeavesNoRecordNoRevealAndTheAlert() async {
        let m = model("kyoto", collector: { _ in throw PassportError.saveFailed })
        await m.collect()
        #expect(stampCount == 0 && m.reveal == nil && m.failure == .collect)
        #expect(env.store.state(of: "kyoto") == .notCollected)
        #expect(!m.isWorking, "Try again is possible")
    }

    @Test func tryAgainAfterAFailureCollectsOnce() async {
        var attempts = 0
        let store = env.store
        let m = model("kyoto", collector: { id in attempts += 1; if attempts == 1 { throw PassportError.saveFailed }; return try store.collect(destinationID: id) })
        await m.collect()
        #expect(m.failure == .collect)
        m.failure = nil
        await m.collect()
        #expect(stampCount == 1 && m.reveal != nil && attempts == 2)
    }

    @Test func collectingNeedsNoLocationAndNoSubscription() async {
        await model("tokyo").collect()
        #expect(env.store.state(of: "tokyo") == .collected, "No location provider is consulted and nothing is gated")
    }

    // MARK: Wishlist

    @Test func theWishlistTogglesIsNeverCollectedAndNeverDoubleSaves() throws {
        let m = model("lisbon")
        m.toggleWishlist()
        #expect(env.store.state(of: "lisbon") == .wishlisted && stampCount == 0)
        #expect(StampDetailState(env.store.snapshot().state(of: "lisbon")) == .wishlisted)
        m.toggleWishlist()
        #expect(env.store.state(of: "lisbon") == .notCollected)
        m.toggleWishlist(); m.toggleWishlist(); m.toggleWishlist()
        #expect(try env.container.mainContext.fetchCount(FetchDescriptor<WishlistItem>()) == 1)
    }

    @Test func aCollectedStampCannotBeWishlisted() async throws {
        await model("kyoto").collect()
        model("kyoto").toggleWishlist()
        let wishlisted = try env.container.mainContext.fetchCount(FetchDescriptor<WishlistItem>())
        #expect(env.store.state(of: "kyoto") == .collected && wishlisted == 0)
    }

    // MARK: Remove

    @Test func removingDeletesOnlyTheStampAndLeavesMemoriesAndTrips() async throws {
        await model("kyoto").collect()
        let trip = try env.store.saveTrip(TripDraft(title: "Spring", destinationIDs: ["kyoto"]))
        var d = MemoryDraft(); d.title = "Torii"; d.destinationID = "kyoto"; d.stampID = StampID.make(for: "kyoto"); d.tripID = trip.id
        let memory = try env.store.saveMemory(d)
        let m = model("kyoto")
        m.remove(name: "Kyoto")
        #expect(stampCount == 0 && env.store.state(of: "kyoto") == .notCollected)
        #expect(try env.container.mainContext.fetchCount(FetchDescriptor<MemoryEntry>()) == 1 && memory.title == "Torii")
        #expect(try env.container.mainContext.fetchCount(FetchDescriptor<Trip>()) == 1)
        #expect(env.toasts.current?.message == "Kyoto removed from your passport." && env.toasts.current?.undo == nil, "No Undo: the confirmation states its scope")
        let item = MemoryItem(memory)
        #expect(MemoryDerived.placeState(of: item, catalog: catalog, snapshot: env.store.snapshot()) == .notInPassport)
    }

    @Test func removingAVerifiedStampRemovesItsVerificationAndCollectingAgainIsNotVerified() async throws {
        try env.store.recordVerification(destinationID: "paris", verification: Fixture.verification())
        #expect(env.store.state(of: "paris") == .verified)
        model("paris").remove(name: "Paris")
        #expect(env.store.state(of: "paris") == .notCollected)
        await model("paris").collect()
        #expect(env.store.stamp(forDestination: "paris")?.isVerified == false, "A verified stamp never comes back verified without a new visit")
    }

    @Test func aFailedRemoveChangesNothingAndShowsTheFailureAlert() async throws {
        await model("kyoto").collect()
        let m = model("kyoto", remover: { _ in throw PassportError.saveFailed })
        m.remove(name: "Kyoto")
        #expect(m.failure == .remove && stampCount == 1 && env.toasts.current == nil)
    }

    // MARK: Verify keeps the record

    @Test func verifyingUpdatesTheSameRecordAndKeepsTheCollectionDate() async throws {
        await model("kyoto").collect()
        let before = try #require(env.store.stamp(forDestination: "kyoto"))
        let (id, date) = (before.stampID, before.collectedAt)
        try env.store.recordVerification(destinationID: "kyoto", verification: Fixture.verification())
        let after = try #require(env.store.stamp(forDestination: "kyoto"))
        #expect(stampCount == 1 && after.stampID == id && after.collectedAt == date && after.isVerified)
        #expect(StampDetailState(env.store.state(of: "kyoto")).isVerified)
    }

    // MARK: Postmark presentation

    @Test func thePostmarkChoiceIsKeptPerStamp() {
        let m = model("kyoto")
        #expect(!m.isPostmarkHidden(stampID: "stamp.kyoto"))
        m.setPostmarkHidden(true, stampID: "stamp.kyoto")
        #expect(m.isPostmarkHidden(stampID: "stamp.kyoto") && !m.isPostmarkHidden(stampID: "stamp.paris"))
        m.setPostmarkHidden(false, stampID: "stamp.kyoto")
        #expect(!m.isPostmarkHidden(stampID: "stamp.kyoto"))
    }

    @Test func thePostmarkChoiceSurvivesARelaunch() {
        let defaults = UserDefaults(suiteName: "stamp-postmark-\(UUID().uuidString)")!
        PreferencesStore(defaults: defaults).setPostmarkHidden(true, for: "stamp.kyoto")
        #expect(PreferencesStore(defaults: defaults).isPostmarkHidden("stamp.kyoto"))
    }

    // MARK: Derived values

    @Test func collectionProgressCountsCollectedStampsOnly() async throws {
        func summary() -> StampCollectionSummary? { StampDetailDerived.summary(of: "paris", catalog: catalog, snapshot: env.store.snapshot()) }
        #expect(summary()?.have == 0 && summary()?.total == 3 && summary()?.title == "World Icons")
        try env.store.addToWishlist(destinationID: "machu")
        #expect(summary()?.have == 0, "Wishlisted is not collected")
        await model("paris").collect()
        await model("machu").collect()
        #expect(summary()?.have == 2)
        model("paris").remove(name: "Paris")
        #expect(summary()?.have == 1, "Progress updates at once after a removal")
    }

    @Test func relatedStampsAreTheSameCollectionInCatalogOrderWithTheirOwnStates() async throws {
        await model("kyoto").collect()
        try env.store.addToWishlist(destinationID: "machu")
        let related = StampDetailDerived.related(to: "paris", catalog: catalog, snapshot: env.store.snapshot())
        #expect(related.map(\.destinationID) == ["machu", "kyoto"])
        #expect(related.map(\.state) == [.wishlisted, .collectedManual])
        #expect(StampDetailDerived.related(to: "lisbon", catalog: catalog, snapshot: env.store.snapshot()).isEmpty, "No collection: no section")
        let wide = DiscoverFixture.catalog((0..<8).map { .init(id: "p\($0)", name: "Place \($0)") }, collections: [(id: "big", title: "Big", ids: (0..<8).map { "p\($0)" })])
        #expect(StampDetailDerived.related(to: "p0", catalog: wide, snapshot: .empty).map(\.destinationID) == ["p1", "p2", "p3", "p4"], "At most four")
    }
}
