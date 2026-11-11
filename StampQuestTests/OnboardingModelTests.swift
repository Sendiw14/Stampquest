import Testing
import Foundation
import SwiftData
@testable import StampQuest

@MainActor
final class StubCollector: StampCollecting {
    var error: Error?
    private(set) var stamps: [String: UserStamp] = [:]

    func collect(_ destination: StampDestination) throws -> UserStamp {
        if let error { throw error }
        let stamp = UserStamp(stampID: "stamp." + destination.id, destinationID: destination.id, titleSnapshot: destination.name,
                              countryCodeSnapshot: "XX", collectedAt: .now, method: .manual)
        stamps[destination.id] = stamp
        return stamp
    }

    func existing(_ destination: StampDestination) -> UserStamp? { stamps[destination.id] }
}

@MainActor
struct OnboardingModelTests {
    let repository = InMemoryOnboardingRepository()
    let collector = StubCollector()
    let purchases = MockPurchaseService()
    var completed: Box = Box()

    @MainActor final class Box { var covers: [CoverStyle] = [] }

    func makeModel(plus: Bool = false, repository: OnboardingRepository? = nil) -> OnboardingModel {
        let box = completed
        return OnboardingModel(repository: repository ?? self.repository, collector: collector, purchases: purchases,
                               flags: FeatureFlags(plusPaywallEnabled: plus), now: { Date(timeIntervalSince1970: 1_000) },
                               complete: { box.covers.append($0) })
    }

    @Test func freshModelStartsAtWelcomeWithNothingSelected() {
        let model = makeModel()
        #expect(model.path.isEmpty && model.interests.isEmpty && model.firstStamp == nil)
        #expect(model.coverStyle == .harbor && model.coverName.isEmpty && model.verification == .undecided)
        #expect(model.plusOutcome == .notShown && !model.isComplete)
    }

    @Test func passportReadyContinueFinishesWhenPlusIsOff() {
        let model = makeModel()
        model.continueFrom(nil)
        for route in [OnboardingRoute.interests, .firstStamp, .verification, .cover, .passportReady] { model.continueFrom(route) }
        #expect(model.path == [.interests, .firstStamp, .verification, .cover, .passportReady])
        #expect(model.isComplete && completed.covers == [.harbor])
    }

    @Test func passportReadyContinueGoesToPlusWhenPlusIsOnAndOfferFinishesFree() {
        let model = makeModel(plus: true)
        model.continueFrom(nil)
        for route in [OnboardingRoute.interests, .firstStamp, .verification, .cover, .passportReady] { model.continueFrom(route) }
        #expect(model.path.last == .plus && !model.isComplete)
        model.finishFromOffer()
        #expect(model.isComplete && model.plusOutcome == .dismissed)
    }

    @Test func aPlusPurchaseFinishesOnboarding() {
        let model = makeModel(plus: true)
        model.finishAfterPurchase()
        #expect(model.isComplete && model.plusOutcome == .subscribed)
    }

    @Test func skipAppliesTheDocumentedSideEffects() {
        let model = makeModel()
        model.setInterests([.coasts])
        model.skip(from: .interests)
        #expect(model.interests.isEmpty && model.path == [.firstStamp])
        model.skip(from: .firstStamp)
        #expect(model.firstStamp == nil && model.path.last == .verification)
        model.skip(from: .verification)
        #expect(model.verification == .skipped && model.path.last == .cover)
        model.coverName = "Alex"
        model.selectCover(.forest)
        model.skip(from: .cover)
        #expect(model.coverStyle == .harbor && model.coverName.isEmpty, "Skip means the default cover and no name")
        #expect(model.path.last == .passportReady && !model.isComplete, "Skip goes to Passport ready like Continue")
    }

    @Test func backPopsAndNeverPopsTheRoot() {
        let model = makeModel()
        model.back()
        #expect(model.path.isEmpty)
        model.continueFrom(nil)
        model.back()
        #expect(model.path.isEmpty)
    }

    @Test func firstStampIsSetOnlyAfterASuccessfulSave() async throws {
        let model = makeModel()
        collector.error = PassportError.saveFailed
        await #expect(throws: PassportError.self) { try await model.collectFirstStamp(.paris) }
        #expect(model.firstStamp == nil)
        collector.error = nil
        try await model.collectFirstStamp(.paris)
        #expect(model.firstStamp?.destinationID == StampDestination.paris.id)
    }

    @Test func theFirstStampChoiceIsLockedOnceSaved() async throws {
        let model = makeModel()
        try await model.collectFirstStamp(.paris)
        try await model.collectFirstStamp(.kyoto)
        #expect(model.firstStamp?.destinationID == StampDestination.paris.id)
        #expect(collector.existing(.kyoto) == nil, "a second first stamp is never created")
    }

    @Test func plusCoverWithoutEntitlementIsNeverApplied() {
        let model = makeModel(plus: true)
        model.selectCover(.clay)
        model.selectCover(.midnight)
        #expect(model.coverStyle == .midnight && model.pendingPlusCover == .midnight)
        #expect(model.appliedCover == .clay, "falls back to the last free cover")
        purchases.isPlusEntitled = true
        #expect(model.appliedCover == .midnight)
    }

    @Test func everyStepIsWrittenThroughAndRestoredOnRelaunch() async throws {
        let model = makeModel()
        model.setInterests([.coasts, .food])
        model.continueFrom(nil)
        model.continueFrom(.interests)
        try await model.collectFirstStamp(.santorini)
        model.setVerification(.enabled)
        model.continueFrom(.firstStamp)
        model.selectCover(.forest)
        let saved = try repository.load()
        #expect(saved.interests == [.coasts, .food] && saved.verification == .enabled && saved.coverStyle == .forest)
        #expect(saved.reached == .verification)

        let relaunched = makeModel()
        #expect(relaunched.path == [.interests, .firstStamp, .verification])
        #expect(relaunched.interests == [.coasts, .food] && relaunched.coverStyle == .forest)
        #expect(relaunched.firstStamp?.destinationID == StampDestination.santorini.id, "never re-collected")
    }

    @Test func revisitingAnEarlierStepIsMarkedSoItDoesNotReplay() {
        let model = makeModel()
        #expect(!model.isRevisit(nil))
        model.continueFrom(nil)
        model.continueFrom(.interests)
        #expect(model.isRevisit(nil) && model.isRevisit(.interests) && !model.isRevisit(.firstStamp))
    }

    @Test func aFailingRepositoryDoesNotBlockTheFlow() {
        let failing = InMemoryOnboardingRepository()
        failing.failsOnSave = true
        let model = makeModel(repository: failing)
        model.continueFrom(nil)
        #expect(model.path == [.interests] && model.lastSaveFailed)
    }
}

@MainActor
struct PersistenceTests {
    @Test func swiftDataRepositoryRoundTripsAndKeepsOneRow() throws {
        let container = try Fixture.container()
        let repo = SwiftDataOnboardingRepository(context: container.mainContext)
        #expect(try repo.load() == OnboardingProgress())
        var progress = OnboardingProgress(interests: [.mountains, .history], verification: .denied, coverStyle: .forest, name: "Alex",
                                          reached: .cover, completedAt: Date(timeIntervalSince1970: 5))
        try repo.save(progress)
        progress.name = "Sam"
        try repo.save(progress)
        #expect(try repo.load() == progress)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PassportProfile>()) == 1)
    }

    @Test func unknownStoredValuesFallBackToDefaults() throws {
        let container = try Fixture.container()
        let profile = PassportProfile(createdAt: .now)
        profile.coverStyleRaw = "gone"
        profile.verificationRaw = "gone"
        profile.reachedRouteRaw = "gone"
        profile.interestRaws = ["coasts", "gone"]
        container.mainContext.insert(profile)
        let loaded = try SwiftDataOnboardingRepository(context: container.mainContext).load()
        #expect(loaded.coverStyle == .harbor && loaded.verification == .undecided && loaded.reached == nil && loaded.interests == [.coasts])
    }

    @Test func versionOneStoreOpensUnderVersionTwoAndKeepsItsStamps() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sq-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Passport.store")

        do {
            let v1 = Schema(versionedSchema: StampQuestSchemaV1.self)
            let container = try ModelContainer(for: v1, configurations: [ModelConfiguration("Passport", schema: v1, url: url, cloudKitDatabase: .none)])
            container.mainContext.insert(UserStamp(stampID: "stamp.a", destinationID: "a", titleSnapshot: "Alpha", countryCodeSnapshot: "FR",
                                                   collectedAt: .now, method: .manual))
            try container.mainContext.save()
        }

        let migrated = try PersistenceController.makeContainer(url: url)
        #expect(try migrated.mainContext.fetchCount(FetchDescriptor<UserStamp>()) == 1)
        migrated.mainContext.insert(PassportProfile(createdAt: .now))
        try migrated.mainContext.save()
        #expect(try migrated.mainContext.fetchCount(FetchDescriptor<PassportProfile>()) == 1)
    }

    private static let onboardingCatalog: Catalog = {
        let dests = StampDestination.catalog.map { Fixture.destinationJSON(id: $0.id, name: $0.name) }
        let meta = Fixture.metaJSON(collections: Fixture.collectionJSON(id: "c", destinations: StampDestination.catalog.map(\.id)))
        // swiftlint:disable:next force_try
        return try! CatalogLoader.build(metaData: Data(meta.utf8), destinationFiles: [Fixture.filesJSON(dests)])
    }()

    @Test func collectUseCaseSavesOnceAndFindsTheExistingStamp() async throws {
        let container = try Fixture.container()
        let store = PassportStore(context: container.mainContext, catalog: Self.onboardingCatalog)
        let useCase = CollectStampUseCase(store: store)
        #expect(useCase.existing(.paris) == nil)
        let first = try await useCase.collect(.paris)
        let second = try await useCase.collect(.paris)
        #expect(first === second, "idempotent")
        #expect(useCase.existing(.paris) === first)
        #expect(first.state == .collected, "manual collecting is never shown as verified")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<UserStamp>()) == 1)
    }

    @Test func collectUseCaseRejectsADestinationMissingFromTheCatalog() async throws {
        let container = try Fixture.container()
        let store = PassportStore(context: container.mainContext, catalog: Fixture.catalog)
        await #expect(throws: PassportError.self) { _ = try await CollectStampUseCase(store: store).collect(.paris) }
    }

    @Test func finishingOnboardingWithTheRealRepositoryRestoresAsComplete() throws {
        let container = try Fixture.container()
        let repo = SwiftDataOnboardingRepository(context: container.mainContext)
        let model = OnboardingModel(repository: repo, collector: StubCollector(), purchases: MockPurchaseService(), flags: FeatureFlags(),
                                    complete: { _ in })
        model.finish()
        let again = OnboardingModel(repository: repo, collector: StubCollector(), purchases: MockPurchaseService(), flags: FeatureFlags(),
                                    complete: { _ in })
        #expect(again.isComplete)
    }
}
