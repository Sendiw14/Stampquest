import Foundation
import Observation

/// State of the "Your passport is ready" screen. It reads saved state and the current location authorization, and writes
/// only the time the passport was first shown as ready.
@MainActor
@Observable
final class PassportReadyViewModel {
    let model: OnboardingModel
    let location: LocationProviding
    private(set) var isOpen = false
    /// Counts every open and close, so effects can tell a new change from the same state.
    private(set) var toggleCount = 0
    private(set) var authorization: LocationAuthorization

    private let now: () -> Date

    init(model: OnboardingModel, location: LocationProviding, now: @escaping () -> Date = { .now }) {
        self.model = model
        self.location = location
        self.now = now
        authorization = location.authorization
    }

    /// The page's and summary's content, from saved state. Read the authorization again on appear: it can change in Settings.
    var content: ReadyContent {
        let stamp = model.firstStamp.flatMap { saved in
            StampDestination.with(id: saved.destinationID).flatMap(StarterStamp.init).map { (stamp: $0, collectedAt: saved.collectedAt) }
        }
        return ReadyContent(holderName: model.coverName, cover: model.coverStyle, isEntitled: model.isPlusEntitled, firstStamp: stamp, verification: model.verification,
                            authorization: authorization, issuedAt: model.passportIssuedAt ?? now(), now: now())
    }

    /// The first time on this screen: remember when the passport was issued, and read the live permission status.
    func appeared() {
        model.markPassportIssued()
        authorization = location.authorization
    }

    /// The cover swings open by itself after the intro.
    func autoOpen() {
        guard !isOpen else { return }
        setOpen(true)
    }

    /// A tap on the passport. The latest target state wins.
    func toggle() { setOpen(!isOpen) }

    func showOpen() { if !isOpen { isOpen = true } }

    private func setOpen(_ value: Bool) {
        isOpen = value
        toggleCount += 1
    }

    /// "Continue": to Plus when the flag is on, otherwise onboarding finishes.
    func continueTapped() { model.continueFrom(.passportReady) }
}
