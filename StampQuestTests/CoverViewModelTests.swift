import Testing
import Foundation
@testable import StampQuest

@MainActor
struct CoverViewModelTests {
    let repository = InMemoryOnboardingRepository()
    let purchases = MockPurchaseService()
    let completed = Box()

    @MainActor final class Box { var covers: [CoverStyle] = [] }

    func makeModel(plus: Bool = false, repository: OnboardingRepository? = nil) -> OnboardingModel {
        let box = completed
        return OnboardingModel(repository: repository ?? self.repository, collector: StubCollector(), purchases: purchases,
                               flags: FeatureFlags(plusPaywallEnabled: plus), complete: { box.covers.append($0) })
    }

    @Test func flagOffShowsThreeFreeCoversAndNoTraceOfPlus() {
        let vm = CoverViewModel(model: makeModel())
        #expect(vm.covers == [.clay, .forest, .harbor] && !vm.showsPlus)
        #expect(vm.selected == .harbor, "Harbor is the default")
        vm.select(.midnight)
        #expect(vm.selected == .harbor, "a Plus cover cannot be selected when the flag is off")
    }

    @Test func flagOnShowsFiveCoversInOrder() {
        let vm = CoverViewModel(model: makeModel(plus: true))
        #expect(vm.covers == [.clay, .forest, .midnight, .harbor, .rosewood] && vm.showsPlus)
        #expect(vm.selectedIndex == 3)
    }

    @Test func continueSavesStyleAndSanitizedNameThenFinishesWhenPlusIsOff() throws {
        let model = makeModel()
        let vm = CoverViewModel(model: model)
        vm.select(.forest)
        vm.setName("   Alex    Rivera  ")
        vm.continueTapped()
        let saved = try repository.load()
        #expect(saved.coverStyle == .forest && saved.name == "Alex Rivera")
        #expect(model.path == [.passportReady] && !model.isComplete, "Continue goes to the passport-ready screen")
    }

    @Test func continueRoutesToPlusWhenThePaywallIsOn() {
        let model = makeModel(plus: true)
        let vm = CoverViewModel(model: model)
        vm.continueTapped()
        #expect(model.path == [.passportReady] && !model.isComplete)
    }

    @Test func skipMeansDefaultCoverAndNoName() throws {
        let model = makeModel()
        let vm = CoverViewModel(model: model)
        vm.select(.clay)
        vm.setName("Alex")
        vm.skipTapped()
        #expect(model.coverStyle == .harbor && model.coverName.isEmpty)
        let saved = try repository.load()
        #expect(saved.name.isEmpty && model.path == [.passportReady])
    }

    @Test func aPlusCoverWithoutEntitlementKeepsTheSelectionAndAppliesTheFirstFreeCover() throws {
        let model = makeModel(plus: true)
        let vm = CoverViewModel(model: model)
        vm.select(.clay)
        vm.select(.midnight)
        vm.continueTapped()
        #expect(model.pendingPlusCover == .midnight, "remembered so Settings can offer it later")
        let saved = try repository.load()
        #expect(model.appliedCover == .clay && saved.coverStyle == .midnight, "the stored selection is kept, the applied cover is Terracotta")
        // Never blocked: Continue went on.
        #expect(model.path == [.passportReady])
    }

    @Test func aPlusCoverWithEntitlementIsApplied() {
        purchases.isPlusEntitled = true
        let model = makeModel(plus: true)
        let vm = CoverViewModel(model: model)
        vm.select(.rosewood)
        vm.continueTapped()
        #expect(model.appliedCover == .rosewood && model.pendingPlusCover == nil)
    }

    @Test func revisitRestoresTheSavedCoverAndName() {
        let model = makeModel()
        let first = CoverViewModel(model: model)
        first.select(.clay)
        first.setName("Sam")
        first.continueTapped()

        let relaunched = makeModel()
        let again = CoverViewModel(model: relaunched)
        #expect(again.selected == .clay && again.typedName == "Sam" && again.displayName == "Sam")
    }

    @Test func aNameOfOnlySpacesShowsNoNameLine() {
        let vm = CoverViewModel(model: makeModel())
        vm.setName("     ")
        #expect(vm.displayName.isEmpty)
        vm.setName(String(repeating: "x", count: 40))
        #expect(vm.displayName.count == 24)
    }

    @Test func nameStartsEmpty() {
        #expect(CoverViewModel(model: makeModel()).displayName.isEmpty)
    }
}

/// F1: one source of truth for the cover.
@MainActor
struct CoverSelectionTests {
    let repository = InMemoryOnboardingRepository()
    let purchases = MockPurchaseService()

    func makeModel(plus: Bool = false, repository: OnboardingRepository? = nil) -> OnboardingModel {
        OnboardingModel(repository: repository ?? self.repository, collector: StubCollector(), purchases: purchases,
                        flags: FeatureFlags(plusPaywallEnabled: plus), complete: { _ in })
    }

    @Test func f1_defaultAgreesEverywhere() {
        let model = makeModel()
        let vm = CoverViewModel(model: model)
        #expect(vm.selected == CoverStyle.default && model.coverStyle == CoverStyle.default && vm.selectedIndex == vm.covers.firstIndex(of: .default))
    }

    @Test func f1_aSwatchTapOrSwipeIsStoredAtOnce() throws {
        let model = makeModel()
        let vm = CoverViewModel(model: model)
        vm.select(.forest)
        let saved = try repository.load()
        #expect(vm.selected == .forest && model.coverStyle == .forest && saved.coverStyle == .forest)
        vm.select(.clay)
        #expect(model.coverStyle == .clay && vm.selectedIndex == 0)
    }

    @Test func f1_backRestoresTheSameCover() {
        let model = makeModel()
        let first = CoverViewModel(model: model)
        first.select(.forest)
        first.continueTapped()
        model.back()
        #expect(CoverViewModel(model: model).selected == .forest, "entering Cover again shows the stored selection")
    }

    @Test func f1_relaunchRestoresTheSameCover() {
        let first = makeModel()
        CoverViewModel(model: first).select(.forest)
        let relaunched = makeModel()
        #expect(relaunched.coverStyle == .forest && CoverViewModel(model: relaunched).selected == .forest)
    }

    @Test func f1_aPlusCoverWithoutPlusIsKeptButShownAsTheResolvedCover() throws {
        let model = makeModel(plus: true)
        CoverViewModel(model: model).select(.midnight)
        #expect(model.coverStyle == .midnight && model.appliedCover == .clay)
        let again = CoverViewModel(model: model)
        #expect(again.selected == .clay && again.selectedIndex == 0, "hero, ring and label all show the resolved cover")
        again.continueTapped()
        let saved = try repository.load()
        #expect(model.coverStyle == .midnight && saved.coverStyle == .midnight, "Continue does not overwrite the stored selection")
    }

    @Test func f1_plusEntitledShowsThePlusCover() {
        purchases.isPlusEntitled = true
        let model = makeModel(plus: true)
        CoverViewModel(model: model).select(.rosewood)
        #expect(CoverViewModel(model: model).selected == .rosewood && model.appliedCover == .rosewood)
    }
}
