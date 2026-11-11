import Foundation

/// Everything onboarding has learned so far. One value is written after every step so a relaunch resumes
/// where the person stopped. The first stamp is not here: it lives in the passport (`UserStamp`).
nonisolated struct OnboardingProgress: Equatable, Sendable {
    var interests: Set<Interest> = []
    var verification: VerificationChoice = .undecided
    var coverStyle: CoverStyle = .default
    var name = ""
    /// Furthest screen reached; nil means Welcome.
    var reached: OnboardingRoute?
    var completedAt: Date?
    /// When the passport was first shown as ready; set once.
    var passportIssuedAt: Date?

    var isComplete: Bool { completedAt != nil }
}
