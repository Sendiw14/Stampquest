import Foundation
import Observation

/// Selection state for the Interests screen. `OnboardingModel.interests` is the source of truth, so Back from
/// First stamp restores exactly what was picked.
@MainActor
@Observable
final class InterestsViewModel {
    enum Hint: Equatable { case none, count(Int) }

    let model: OnboardingModel

    init(model: OnboardingModel) { self.model = model }

    var selected: Set<Interest> { model.interests }
    var canContinue: Bool { !selected.isEmpty }
    var hint: Hint { selected.isEmpty ? .none : .count(selected.count) }

    func isSelected(_ interest: Interest) -> Bool { selected.contains(interest) }

    /// Returns the new selection count, for the VoiceOver announcement.
    @discardableResult
    func toggle(_ interest: Interest) -> Int {
        var next = model.interests
        if !next.insert(interest).inserted { next.remove(interest) }
        model.setInterests(next)
        return next.count
    }

    /// Persists the selection (done by `setInterests`) and moves on. Ignored when nothing is picked.
    func continueTapped() {
        guard canContinue else { return }
        model.continueFrom(.interests)
    }

    /// Skip always works and leaves interests empty.
    func skip() { model.skip(from: .interests) }
}
