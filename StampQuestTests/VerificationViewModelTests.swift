import Testing
import Foundation
@testable import StampQuest

/// A location provider whose permission prompt never answers: the screen must not hang.
@MainActor
final class HangingLocationProvider: LocationProviding {
    var authorization: LocationAuthorization { .notDetermined }
    func servicesEnabled() async -> Bool { true }
    func requestAuthorization() async -> LocationAuthorization { await withCheckedContinuation { (_: CheckedContinuation<LocationAuthorization, Never>) in } }
    func currentReading(timeout: Duration) async throws -> LocationReading { throw VerificationFailure.unavailable }
}

@MainActor
struct VerificationViewModelTests {
    let repository = InMemoryOnboardingRepository()
    let location = MockLocationProvider()
    let clock = Date(timeIntervalSince1970: 1_800_000_000)

    func makeModel() -> OnboardingModel {
        OnboardingModel(repository: repository, collector: StubCollector(), purchases: MockPurchaseService(), flags: FeatureFlags(), complete: { _ in })
    }

    func makeVM(_ model: OnboardingModel, timeout: Duration = .seconds(30)) -> VerificationViewModel {
        VerificationViewModel(model: model, location: location, requestTimeout: timeout, now: { clock }, sleeper: { _ in })
    }

    private func assertNothingTouched(_ model: OnboardingModel) {
        #expect(location.promptCount == 0 && location.readingRequests == 0, "no location call")
        #expect(model.verification == .undecided && model.path.isEmpty, "nothing stored, nowhere navigated")
    }

    @Test func togglingThePreviewTouchesNeitherTheStoreNorLocation() {
        let model = makeModel()
        let vm = makeVM(model)
        #expect(vm.preview == .collected)
        vm.select(.verified)
        vm.select(.collected)
        vm.select(.verified)
        assertNothingTouched(model)
        #expect(vm.permission == .idle && vm.successCount == 0)
    }

    @Test func reSelectingTheSelectedSideDoesNothing() {
        let vm = makeVM(makeModel())
        vm.select(.collected)
        #expect(vm.landingID == 0 && vm.verifiedCount == 0)
        vm.select(.verified)
        vm.select(.verified)
        #expect(vm.landingID == 1 && vm.verifiedCount == 1)
    }

    @Test func tenRapidTapsEndInExactlyOneFinalState() {
        let vm = makeVM(makeModel())
        for index in 0..<10 { vm.select(index.isMultiple(of: 2) ? .verified : .collected) }
        #expect(vm.preview == .collected && vm.landingID == 10 && vm.verifiedCount == 5)
    }

    @Test func theCTAOpensTheExplainerAndDoesNotAskForLocation() {
        let model = makeModel()
        let vm = makeVM(model)
        vm.ctaTapped()
        #expect(vm.permission == .explaining && vm.isExplaining)
        assertNothingTouched(model)
    }

    @Test func grantedStoresEnabledRequestsSuccessAndGoesToCover() async {
        let model = makeModel()
        location.status = .notDetermined
        location.statusAfterPrompt = .authorized
        let vm = makeVM(model)
        vm.ctaTapped()
        await vm.explainerContinued()
        #expect(location.promptCount == 1 && location.readingRequests == 0, "authorization only, never a reading")
        #expect(model.verification == .enabled && vm.permission == .enabled && vm.successCount == 1)
        #expect(model.path == [.cover])
    }

    @Test(arguments: [LocationAuthorization.denied, .restricted])
    func deniedOrRestrictedStoresDeclinedWithNoSuccessAndShowsTheNotice(status: LocationAuthorization) async {
        let model = makeModel()
        location.status = .notDetermined
        location.statusAfterPrompt = status
        let vm = makeVM(model)
        vm.ctaTapped()
        await vm.explainerContinued()
        #expect(model.verification == .denied && vm.permission == .declined && vm.successCount == 0)
        #expect(vm.showsDeclinedNotice && vm.ctaIsContinue && model.path.isEmpty, "stays on the screen")
        vm.ctaTapped()
        #expect(model.path == [.cover], "the next tap advances")
    }

    @Test func dismissingTheExplainerCountsAsDeclinedWithoutAskingIOS() {
        let model = makeModel()
        let vm = makeVM(model)
        vm.ctaTapped()
        vm.explainerDismissed()
        #expect(model.verification == .denied && vm.showsDeclinedNotice && vm.ctaIsContinue)
        #expect(location.promptCount == 0 && location.readingRequests == 0)
        vm.explainerDismissed()
        #expect(model.verification == .denied, "a second dismissal changes nothing")
    }

    @Test func notNowGoesToCoverAsDeclinedWithNoLocationCall() {
        let model = makeModel()
        makeVM(model).notNowTapped()
        #expect(model.verification == .denied && model.path == [.cover])
        #expect(location.promptCount == 0 && location.readingRequests == 0)
    }

    @Test func skipGoesToCoverWithoutLocationOrADeclinedMark() {
        let model = makeModel()
        makeVM(model).skipTapped()
        #expect(model.verification == .skipped && model.path == [.cover])
        #expect(location.promptCount == 0 && location.readingRequests == 0)
    }

    @Test func aPromptThatNeverAnswersDoesNotHangTheScreen() async {
        let model = makeModel()
        let vm = VerificationViewModel(model: model, location: HangingLocationProvider(), requestTimeout: .milliseconds(50),
                                       now: { clock }, sleeper: { _ in })
        vm.ctaTapped()
        await vm.explainerContinued()
        #expect(vm.permission == .idle && model.verification == .undecided && model.path.isEmpty)
    }

    @Test func theSealDateComesFromTheInjectedClock() {
        let vm = makeVM(makeModel())
        #expect(vm.exampleDate == clock)
        #expect(OnboardingFormat.stampDate(vm.exampleDate, locale: Locale(identifier: "en_GB"), timeZone: TimeZone(identifier: "UTC") ?? .gmt) == "15 JAN 2027")
    }

    @Test func requestsWhenInUseOnlyAndNeverReadsALocation() async {
        let model = makeModel()
        location.status = .notDetermined
        let vm = makeVM(model)
        vm.ctaTapped()
        await vm.explainerContinued()
        #expect(location.readingRequests == 0)
    }
}
