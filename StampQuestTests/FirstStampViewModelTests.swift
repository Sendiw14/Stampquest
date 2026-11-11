import Testing
import Foundation
@testable import StampQuest

/// A collector that suspends inside `collect` until told to finish, to prove nothing reveals before the save returns.
@MainActor
final class SuspendingCollector: StampCollecting {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var stamps: [String: UserStamp] = [:]
    var error: Error?
    private(set) var callCount = 0

    func collect(_ destination: StampDestination) async throws -> UserStamp {
        callCount += 1
        await withCheckedContinuation { continuation = $0 }
        if let error { throw error }
        let stamp = UserStamp(stampID: "stamp." + destination.id, destinationID: destination.id, titleSnapshot: destination.name,
                              countryCodeSnapshot: "XX", collectedAt: Date(timeIntervalSince1970: 1_000), method: .manual)
        stamps[destination.id] = stamp
        return stamp
    }

    func existing(_ destination: StampDestination) -> UserStamp? { stamps[destination.id] }
    func finish() { continuation?.resume(); continuation = nil }
}

@MainActor
struct FirstStampViewModelTests {
    let repository = InMemoryOnboardingRepository()

    func makeModel(_ collector: StampCollecting) -> OnboardingModel {
        OnboardingModel(repository: repository, collector: collector, purchases: MockPurchaseService(), flags: FeatureFlags(), complete: { _ in })
    }

    @Test func aSavedStampLeadsToCollectedAndStartsTheReveal() async {
        let model = makeModel(StubCollector())
        let vm = FirstStampViewModel(model: model)
        #expect(vm.phase == .choosing && vm.reveal == .idle && !vm.isCollected && !vm.isNavigationLocked)
        await vm.tap(.paris)
        #expect(vm.phase == .collected(.paris) && vm.reveal == .playing && vm.isCollected)
        #expect(model.firstStamp?.destinationID == StampDestination.paris.id)
    }

    @Test func theRevealNeverStartsBeforeTheSaveReturns() async {
        let collector = SuspendingCollector()
        let model = makeModel(collector)
        let vm = FirstStampViewModel(model: model)
        let task = Task { await vm.tap(.kyoto) }
        for _ in 0..<5 { await Task.yield() }
        #expect(vm.phase == .saving(.kyoto) && vm.reveal == .idle && vm.isNavigationLocked && !vm.isCollected)
        #expect(model.firstStamp == nil)
        collector.finish()
        await task.value
        #expect(vm.phase == .collected(.kyoto) && vm.reveal == .playing && !vm.isNavigationLocked)
    }

    @Test func aSecondTapIsIgnoredWhileSavingAndAfterCollecting() async {
        let collector = SuspendingCollector()
        let vm = FirstStampViewModel(model: makeModel(collector))
        let first = Task { await vm.tap(.paris) }
        for _ in 0..<5 { await Task.yield() }
        await vm.tap(.paris)
        await vm.tap(.santorini)
        #expect(collector.callCount == 1 && !vm.canTap)
        collector.finish()
        await first.value
        await vm.tap(.kyoto)
        #expect(collector.callCount == 1 && vm.phase == .collected(.paris))
    }

    @Test func aFailedSaveLeadsToFailedAndRetryLeadsToCollected() async {
        let collector = StubCollector()
        collector.error = PassportError.saveFailed
        let model = makeModel(collector)
        let vm = FirstStampViewModel(model: model)
        await vm.tap(.paris)
        #expect(vm.phase == .failed(.paris, .saveFailed) && vm.failure == .saveFailed && vm.failureCount == 1)
        #expect(model.firstStamp == nil && !vm.isCollected && vm.reveal == .idle, "no stamp, no reveal, Continue stays disabled")
        collector.error = nil
        await vm.retry()
        #expect(vm.phase == .collected(.paris) && vm.failure == nil && vm.reveal == .playing)
    }

    @Test func skipAfterCollectingKeepsTheStamp() async {
        let model = makeModel(StubCollector())
        let vm = FirstStampViewModel(model: model)
        await vm.tap(.santorini)
        model.skip(from: .firstStamp)
        #expect(model.firstStamp?.destinationID == StampDestination.santorini.id)
        #expect(model.path == [.verification])
    }

    @Test func reEnteringTheStepRestoresCollectedWithoutAReveal() async throws {
        let model = makeModel(StubCollector())
        try await model.collectFirstStamp(.santorini)
        model.setInterests([.cities])
        let vm = FirstStampViewModel(model: model)
        #expect(vm.isRestored && vm.phase == .collected(.santorini) && vm.reveal == .settled)
        #expect(!vm.consumeSuccessHaptic(), "a restored screen never fires the success haptic")
    }

    @Test func interruptingTheRevealJumpsToTheFinalStateExactlyOnce() async {
        let vm = FirstStampViewModel(model: makeModel(StubCollector()))
        #expect(!vm.interruptReveal(), "nothing to interrupt yet")
        await vm.tap(.paris)
        #expect(vm.interruptReveal() && vm.reveal == .settled)
        #expect(!vm.interruptReveal(), "a second tap does nothing")
        vm.revealFinished()
        #expect(vm.reveal == .settled)
    }

    @Test func theSuccessHapticFiresOnceWhoeverGetsThereFirst() async {
        let vm = FirstStampViewModel(model: makeModel(StubCollector()))
        #expect(!vm.consumeSuccessHaptic(), "not before a stamp is saved")
        await vm.tap(.paris)
        #expect(vm.consumeSuccessHaptic())
        #expect(!vm.consumeSuccessHaptic(), "the interruption must not repeat it")
    }

    @Test func deskOrderFollowsTheInterests() {
        let model = makeModel(StubCollector())
        #expect(FirstStampViewModel(model: model).desk == [.paris, .kyoto, .santorini])
        model.setInterests([.coasts])
        #expect(FirstStampViewModel(model: model).desk.first == .santorini)
    }

    @Test func backgroundingWhileSavingSnapsToCollectedWhenTheSaveWentThrough() async {
        let vm = FirstStampViewModel(model: makeModel(StubCollector()))
        await vm.tap(.paris)
        vm.snapToCollectedIfSaved()
        #expect(vm.isCollected)
    }
}
