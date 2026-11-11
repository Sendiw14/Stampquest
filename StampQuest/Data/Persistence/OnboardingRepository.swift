import Foundation
import SwiftData

/// Persists `OnboardingProgress`. One value is written after every step.
@MainActor
protocol OnboardingRepository {
    func load() throws -> OnboardingProgress
    func save(_ progress: OnboardingProgress) throws
}

/// SwiftData implementation: a single `PassportProfile` row.
@MainActor
final class SwiftDataOnboardingRepository: OnboardingRepository {
    private let context: ModelContext
    private let now: () -> Date

    init(context: ModelContext, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
    }

    func load() throws -> OnboardingProgress {
        guard let profile = try fetch() else { return OnboardingProgress() }
        return OnboardingProgress(
            interests: Set(profile.interestRaws.compactMap(Interest.init(rawValue:))),
            verification: VerificationChoice(rawValue: profile.verificationRaw) ?? .undecided,
            coverStyle: CoverStyle(rawValue: profile.coverStyleRaw) ?? .default,
            name: profile.name,
            reached: profile.reachedRouteRaw.flatMap(OnboardingRoute.init(rawValue:)),
            completedAt: profile.onboardingCompletedAt, passportIssuedAt: profile.passportIssuedAt)
    }

    func save(_ progress: OnboardingProgress) throws {
        let profile = try fetch() ?? { let p = PassportProfile(createdAt: now()); context.insert(p); return p }()
        profile.name = progress.name
        profile.coverStyleRaw = progress.coverStyle.rawValue
        profile.interestRaws = progress.interests.map(\.rawValue).sorted()
        profile.verificationRaw = progress.verification.rawValue
        profile.reachedRouteRaw = progress.reached?.rawValue
        profile.onboardingCompletedAt = progress.completedAt
        profile.passportIssuedAt = progress.passportIssuedAt
        do { try context.save() } catch {
            context.rollback()
            throw error
        }
    }

    private func fetch() throws -> PassportProfile? {
        let key = PassportProfile.primaryKey
        var descriptor = FetchDescriptor<PassportProfile>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

/// In-memory implementation for previews and tests that do not need SwiftData.
@MainActor
final class InMemoryOnboardingRepository: OnboardingRepository {
    private(set) var stored = OnboardingProgress()
    var failsOnSave = false

    func load() throws -> OnboardingProgress { stored }

    func save(_ progress: OnboardingProgress) throws {
        if failsOnSave { throw PassportError.saveFailed }
        stored = progress
    }
}
