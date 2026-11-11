import Foundation

/// Screens after Welcome. Welcome is the root of the stack, so it has no route. Passport ready closes the five steps. Plus
/// exists only when the paywall flag is on. Plus's Close opens the exit sheet over it (not a route).
nonisolated enum OnboardingRoute: String, Hashable, CaseIterable, Codable, Sendable {
    case interests, firstStamp, verification, cover, passportReady, plus

    /// Routes in order for the given flags.
    static func flow(plusEnabled: Bool) -> [OnboardingRoute] {
        plusEnabled ? allCases : allCases.filter { $0 != .plus }
    }

    /// Position on the 5-step progress strip (Welcome is step 1). Plus shows no strip.
    var progressStep: Int? {
        switch self {
        case .interests: 2
        case .firstStamp: 3
        case .verification: 4
        case .cover, .passportReady: 5
        case .plus: nil
        }
    }

    static let welcomeProgressStep = 1
    static let progressStepCount = 5

    /// Where Skip goes. Cover's Skip routes like Continue (to Plus, or finish), so it has no fixed target here.
    var skipTarget: OnboardingRoute? {
        switch self {
        case .interests: .firstStamp
        case .firstStamp: .verification
        case .verification: .cover
        case .cover, .passportReady, .plus: nil
        }
    }

    /// Whether the screen has a Skip control.
    var hasSkip: Bool { self != .plus && self != .passportReady }

    /// The route the main call to action goes to. Nil means onboarding finishes.
    func next(plusEnabled: Bool) -> OnboardingRoute? {
        switch self {
        case .interests: .firstStamp
        case .firstStamp: .verification
        case .verification: .cover
        case .cover: .passportReady
        case .passportReady: plusEnabled ? .plus : nil
        case .plus: nil
        }
    }

    /// Whether the screen has a Back control. Plus has none (its Close icon opens the Offer sheet).
    var hasBack: Bool { self != .plus }

    /// Routes to put on the stack when restoring progress: every route up to and including `self`.
    func stack(plusEnabled: Bool) -> [OnboardingRoute] {
        let flow = Self.flow(plusEnabled: plusEnabled)
        guard let index = flow.firstIndex(of: self) else { return [] }
        return Array(flow[...index])
    }
}

/// What the person chose on the verification screen.
nonisolated enum VerificationChoice: String, Codable, Sendable {
    case undecided, enabled, skipped, denied
}
