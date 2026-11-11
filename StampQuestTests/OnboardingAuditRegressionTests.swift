import Testing
import Foundation
@testable import StampQuest

/// One test per audit finding; names carry the id from Docs/Onboarding/BUGS.md.
@MainActor
struct OnboardingAuditRegressionTests {
    @MainActor final class Box { var covers: [CoverStyle] = [] }

    func makeModel(plus: Bool = false, box: Box = Box()) -> OnboardingModel {
        OnboardingModel(repository: InMemoryOnboardingRepository(), collector: StubCollector(), purchases: MockPurchaseService(),
                        flags: FeatureFlags(plusPaywallEnabled: plus), complete: { box.covers.append($0) })
    }

    @Test func OB001_aDoubleTapOnContinueNavigatesOnce() {
        let model = makeModel(plus: true)
        model.continueFrom(nil)
        model.continueFrom(.interests)
        model.continueFrom(.interests)
        #expect(model.path == [.interests, .firstStamp])
    }

    @Test func OB002_finishingTwiceCompletesOnceAndKeepsTheFirstOutcome() {
        let box = Box()
        let model = makeModel(plus: true, box: box)
        model.finishAfterPurchase()
        let completedAt = model.completedAt
        model.finishFromOffer()
        model.finish()
        #expect(box.covers.count == 1)
        #expect(model.plusOutcome == .subscribed && model.completedAt == completedAt)
    }
}
