import Testing
import Foundation
@testable import StampQuest

@MainActor
struct InterestsViewModelTests {
    let repository = InMemoryOnboardingRepository()

    func makeModel() -> OnboardingModel {
        OnboardingModel(repository: repository, collector: StubCollector(), purchases: MockPurchaseService(), flags: FeatureFlags(),
                        complete: { _ in })
    }

    @Test func nothingIsPreselectedAndContinueIsDisabled() {
        let vm = InterestsViewModel(model: makeModel())
        #expect(vm.selected.isEmpty && !vm.canContinue && vm.hint == .none)
    }

    @Test func togglingSelectsDeselectsAndCountsForTheHint() {
        let vm = InterestsViewModel(model: makeModel())
        #expect(vm.toggle(.cities) == 1)
        #expect(vm.canContinue && vm.hint == .count(1))
        #expect(vm.toggle(.coasts) == 2 && vm.hint == .count(2))
        #expect(vm.toggle(.cities) == 1 && !vm.isSelected(.cities) && vm.isSelected(.coasts))
        #expect(vm.toggle(.coasts) == 0 && !vm.canContinue && vm.hint == .none)
    }

    @Test func rapidTogglingNeverDropsOrDesyncs() {
        let vm = InterestsViewModel(model: makeModel())
        for _ in 0..<50 { for interest in Interest.allCases { vm.toggle(interest) } }
        #expect(vm.selected.isEmpty, "50 full passes toggle every tile an even number of times")
        for interest in Interest.allCases { vm.toggle(interest) }
        #expect(vm.selected.count == 6 && vm.hint == .count(6))
    }

    @Test func continueIsIgnoredWithNothingPickedAndPersistsWhenPicked() throws {
        let model = makeModel()
        let vm = InterestsViewModel(model: model)
        vm.continueTapped()
        #expect(model.path.isEmpty)
        vm.toggle(.food)
        vm.continueTapped()
        #expect(model.path == [.firstStamp])
        #expect(try repository.load().interests == [.food], "saved before navigating")
    }

    @Test func skipLeavesInterestsEmptyAndPersistsThat() throws {
        let model = makeModel()
        let vm = InterestsViewModel(model: model)
        vm.toggle(.history)
        vm.skip()
        #expect(model.interests.isEmpty && model.path == [.firstStamp])
        #expect(try repository.load().interests.isEmpty)
    }

    @Test func selectionSurvivesBackAndRelaunch() {
        let model = makeModel()
        InterestsViewModel(model: model).toggle(.coasts)
        model.continueFrom(nil)
        model.continueFrom(.interests)
        model.back()
        #expect(InterestsViewModel(model: model).selected == [.coasts], "Back restores the selection exactly")
        #expect(makeModel().interests == [.coasts], "and so does a relaunch")
    }

    @Test func trayOrderFollowsTheSelection() {
        let model = makeModel()
        InterestsViewModel(model: model).toggle(.coasts)
        #expect(model.starterTray.first == .santorini)
    }
}
