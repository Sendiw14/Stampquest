import Foundation
import Observation

/// Why a stamp was not saved.
enum CollectError: Error, Equatable {
    case saveFailed
}

/// State of the First stamp screen. The reveal never starts before the passport saved the stamp: validate, persist,
/// then animate.
@MainActor
@Observable
final class FirstStampViewModel {
    enum Phase: Equatable {
        case choosing
        case saving(StarterStamp)
        /// Also the restored state.
        case collected(StarterStamp)
        case failed(StarterStamp, CollectError)
    }

    /// The animation that follows a saved stamp.
    enum Reveal: Equatable {
        case idle, playing, settled
    }

    let model: OnboardingModel
    private(set) var phase: Phase
    private(set) var reveal: Reveal
    /// Increments on every failed save so the view can shake the tapped stamp.
    private(set) var failureCount = 0
    /// True when the screen shows an already collected stamp from the start (revisit, relaunch): no animation replay.
    let isRestored: Bool
    private var successHapticPending: Bool

    init(model: OnboardingModel) {
        self.model = model
        if let stamp = model.firstStamp, let starter = StampDestination.with(id: stamp.destinationID).flatMap(StarterStamp.init) {
            phase = .collected(starter)
            reveal = .settled
            isRestored = true
            successHapticPending = false
        } else {
            phase = .choosing
            reveal = .idle
            isRestored = false
            successHapticPending = true
        }
    }

    // MARK: Derived

    /// Desk order follows the interests chosen on the previous screen.
    var desk: [StarterStamp] { model.starterTray.compactMap(StarterStamp.init) }

    var collected: StarterStamp? { if case .collected(let starter) = phase { starter } else { nil } }
    var isCollected: Bool { collected != nil }

    /// The stamp being saved, or the one that failed, so its button can show it.
    var active: StarterStamp? {
        switch phase {
        case .saving(let starter), .collected(let starter), .failed(let starter, _): starter
        case .choosing: nil
        }
    }

    var failure: CollectError? { if case .failed(_, let error) = phase { error } else { nil } }

    /// Back, swipe-back and Skip wait until the save returned.
    var isNavigationLocked: Bool { if case .saving = phase { true } else { false } }

    var canTap: Bool {
        switch phase {
        case .choosing, .failed: true
        case .saving, .collected: false
        }
    }

    var collectedAt: Date? { model.firstStamp?.collectedAt }

    // MARK: Flow

    /// Saves `starter`; taps are ignored unless choosing (or retrying after a failure).
    func tap(_ starter: StarterStamp) async {
        guard canTap else { return }
        phase = .saving(starter)
        do {
            try await model.collectFirstStamp(starter.destination)
            phase = .collected(starter)
            reveal = .playing
        } catch {
            phase = .failed(starter, .saveFailed)
            failureCount += 1
        }
    }

    /// "Try again": runs the failed save once more.
    func retry() async {
        guard case .failed(let starter, _) = phase else { return }
        await tap(starter)
    }

    // MARK: Reveal

    /// A tap during the reveal: jump to the final state. Returns true the first time, so the caller snaps exactly once.
    @discardableResult
    func interruptReveal() -> Bool {
        guard reveal == .playing else { return false }
        reveal = .settled
        return true
    }

    func revealFinished() {
        if reveal == .playing { reveal = .settled }
    }

    /// True once: whoever reaches the moment of contact first (the reveal, or an interruption) fires the success haptic.
    func consumeSuccessHaptic() -> Bool {
        guard successHapticPending, isCollected else { return false }
        successHapticPending = false
        return true
    }

    /// App returned from the background mid-save: if the save succeeded, show the collected state with no replay.
    func snapToCollectedIfSaved() {
        guard case .saving = phase else { return }
        if let stamp = model.firstStamp, let starter = StampDestination.with(id: stamp.destinationID).flatMap(StarterStamp.init) {
            phase = .collected(starter)
            reveal = .settled
        } else {
            phase = .choosing
        }
    }
}
