import Foundation
import Observation

/// State of the Collected / Verified screen. The Collected / Verified control is a preview only: it stores nothing, makes
/// no verification record and never touches location. Location is requested only after "Turn on verified stamps" and the
/// pre-permission sheet's "Continue".
@MainActor
@Observable
final class VerificationViewModel {
    enum Preview: Equatable { case collected, verified }

    enum Permission: Equatable {
        case idle, explaining, requesting
        case enabled, declined
    }

    let model: OnboardingModel
    let location: LocationProviding
    private(set) var preview = Preview.collected
    /// Increments on every switch, so effects and captions follow the latest tap only.
    private(set) var landingID = 0
    /// Increments on every switch to Verified, so the seal's extras replay once per landing.
    private(set) var verifiedCount = 0
    private(set) var permission = Permission.idle
    /// Increments when permission was granted, so the view can fire the success haptic once.
    private(set) var successCount = 0

    private let requestTimeout: Duration
    private let advanceDelay: Duration
    private let now: () -> Date
    private let sleeper: (Duration) async throws -> Void
    private var didNavigate = false

    init(model: OnboardingModel, location: LocationProviding, requestTimeout: Duration = .seconds(30),
         advanceDelay: Duration = .milliseconds(400), now: @escaping () -> Date = { .now },
         sleeper: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.model = model
        self.location = location
        self.requestTimeout = requestTimeout
        self.advanceDelay = advanceDelay
        self.now = now
        self.sleeper = sleeper
    }

    // MARK: Derived

    /// The date printed on the example postmark and on the illustrative seal, from the injected clock.
    var exampleDate: Date { now() }
    var showsDeclinedNotice: Bool { permission == .declined }
    var isExplaining: Bool { permission == .explaining }
    var isRequesting: Bool { permission == .requesting }
    /// "Continue" once the person declined; the next tap advances.
    var ctaIsContinue: Bool { permission == .declined }

    // MARK: Preview

    /// Switches the example. Re-selecting the selected side does nothing; nothing is stored and location is not touched.
    func select(_ newPreview: Preview) {
        guard newPreview != preview else { return }
        preview = newPreview
        landingID += 1
        if newPreview == .verified { verifiedCount += 1 }
    }

    // MARK: Permission

    /// "Turn on verified stamps": first the explainer; once the person declined it reads "Continue" and advances.
    func ctaTapped() {
        switch permission {
        case .idle: permission = .explaining
        case .declined: advance()
        case .explaining, .requesting, .enabled: break
        }
    }

    /// The sheet's "Continue": now, and only now, ask iOS for When In Use. Never a location read.
    func explainerContinued() async {
        guard permission == .explaining else { return }
        permission = .requesting
        guard let result = await requestWithTimeout() else {
            permission = .idle
            return
        }
        if result == .authorized {
            model.setVerification(.enabled)
            permission = .enabled
            successCount += 1
            try? await sleeper(advanceDelay)
            advance()
        } else {
            decline()
        }
    }

    /// The sheet's "Not now", or swiping it away: counts as declined, with no location request.
    func explainerDismissed() {
        guard permission == .explaining else { return }
        decline()
    }

    /// "Not now" on the screen: an explicit decline, then on to Cover.
    func notNowTapped() {
        guard !didNavigate else { return }
        model.setVerification(.denied)
        advance()
    }

    /// The top "Skip": on to Cover with the choice left as "skipped".
    func skipTapped() {
        guard !didNavigate else { return }
        didNavigate = true
        model.skip(from: .verification)
    }

    private func decline() {
        model.setVerification(.denied)
        permission = .declined
    }

    private func advance() {
        guard !didNavigate else { return }
        didNavigate = true
        model.continueFrom(.verification)
    }

    /// Never hangs: a callback that does not arrive within the timeout leaves the screen as it was, button enabled.
    private func requestWithTimeout() async -> LocationAuthorization? {
        let gate = ResumeOnce()
        let location = location, timeout = requestTimeout
        return await withCheckedContinuation { continuation in
            gate.continuation = continuation
            Task { @MainActor in gate.finish(await location.requestAuthorization()) }
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                gate.finish(nil)
            }
        }
    }

    @MainActor
    private final class ResumeOnce {
        var continuation: CheckedContinuation<LocationAuthorization?, Never>?
        func finish(_ value: LocationAuthorization?) {
            continuation?.resume(returning: value)
            continuation = nil
        }
    }
}
