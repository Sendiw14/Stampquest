import Foundation
import Observation
import OSLog

enum PlusOutcome: Equatable { case notShown, dismissed, subscribed }

/// What Passport ready last showed, so a revisit shows the same thing. PROVISIONAL: prompt 06 section 9 defines the fields.
struct ReadySnapshot: Equatable {
    var cover: CoverStyle
    var name: String
    var firstStampID: String?
}

/// Holds everything onboarding has collected and drives the route stack. Every step writes through the
/// repository as it completes; a relaunch resumes at the furthest screen reached.
@MainActor
@Observable
final class OnboardingModel {
    var interests: Set<Interest> = []
    /// Set only after the passport saved the stamp.
    private(set) var firstStamp: UserStamp?
    var verification: VerificationChoice = .undecided
    private(set) var coverStyle: CoverStyle = .default
    var coverName = ""
    /// A Plus cover the person tapped without owning Plus. Never applied.
    private(set) var pendingPlusCover: CoverStyle?
    var readySnapshot: ReadySnapshot?
    var plusOutcome: PlusOutcome = .notShown
    var path: [OnboardingRoute] = []
    private(set) var completedAt: Date?
    /// When the passport was first shown as ready; nil until then.
    private(set) var passportIssuedAt: Date?
    /// When the Plus paywall was first shown; nil until then. Kept in `UserDefaults`, not in the SwiftData store: changing that store's
    /// schema would stop every existing passport from opening.
    private(set) var plusOfferShownAt: Date?
    static let plusOfferShownKey = "onboarding.plusOfferShownAt"
    /// True after a repository write failed. Progress still works in memory; only resuming after a relaunch is lost.
    private(set) var lastSaveFailed = false

    let flags: FeatureFlags
    private var reached: OnboardingRoute?
    private let repository: OnboardingRepository
    private let collector: StampCollecting
    private let purchases: PurchaseService
    private let complete: (CoverStyle) -> Void
    private let now: () -> Date
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "app.stampquest.ios", category: "onboarding")

    init(repository: OnboardingRepository, collector: StampCollecting, purchases: PurchaseService,
         flags: FeatureFlags = .current, now: @escaping () -> Date = { .now }, defaults: UserDefaults = .standard,
         complete: @escaping (CoverStyle) -> Void) {
        self.repository = repository
        self.collector = collector
        self.purchases = purchases
        self.flags = flags
        self.now = now
        self.defaults = defaults
        plusOfferShownAt = defaults.object(forKey: Self.plusOfferShownKey) as? Date
        self.complete = complete
        restore()
    }

    // MARK: Derived

    var isComplete: Bool { completedAt != nil }
    var isPlusEntitled: Bool { purchases.isPlusEntitled }

    /// The selected cover, or the last free cover when a Plus cover is selected without entitlement.
    var appliedCover: CoverStyle { CoverEntitlementResolver.effectiveCover(selected: coverStyle, isEntitled: isPlusEntitled) }

    var availableCovers: [CoverStyle] { CoverStyle.available(plusEnabled: flags.plusPaywallEnabled) }

    /// The stamps to offer, best match first.
    var starterTray: [StampDestination] { StarterTray.rank(for: interests) }

    /// True for a screen before the furthest one reached (nil is Welcome): show its completed state, no replayed animation.
    func isRevisit(_ route: OnboardingRoute?) -> Bool {
        let flow = OnboardingRoute.flow(plusEnabled: flags.plusPaywallEnabled)
        guard let reached, let reachedIndex = flow.firstIndex(of: reached) else { return false }
        guard let route else { return true }
        return (flow.firstIndex(of: route) ?? .max) < reachedIndex
    }

    // MARK: Actions

    func selectCover(_ style: CoverStyle) {
        coverStyle = style
        pendingPlusCover = style.isPlus && !isPlusEntitled ? style : nil
        persist()
    }

    /// Collects the first stamp. `firstStamp` and the saved progress change only if the passport saved it.
    /// Once a first stamp exists the choice is locked: a second call never creates another stamp.
    func collectFirstStamp(_ destination: StampDestination) async throws {
        guard firstStamp == nil else { return }
        let stamp = try await collector.collect(destination)
        firstStamp = stamp
        persist()
    }

    /// Cover's Continue: saves the chosen style and the sanitized name.
    func commitCover(_ style: CoverStyle, name: String) {
        coverName = name
        selectCover(style)
    }

    func setInterests(_ newValue: Set<Interest>) {
        interests = newValue
        persist()
    }

    /// Records the moment the passport was first shown as ready. Set once, never overwritten.
    func markPassportIssued() {
        guard passportIssuedAt == nil else { return }
        passportIssuedAt = now()
        persist()
    }

    /// Records the moment the Plus paywall was first shown. Set once, never overwritten.
    func markPlusOfferShown() {
        guard plusOfferShownAt == nil else { return }
        let date = now()
        plusOfferShownAt = date
        defaults.set(date, forKey: Self.plusOfferShownKey)
    }

    func setVerification(_ choice: VerificationChoice) {
        verification = choice
        persist()
    }

    /// The main call to action on `route` (nil is Welcome): goes to the next screen, or finishes.
    func continueFrom(_ route: OnboardingRoute?) {
        let next = route.map { $0.next(plusEnabled: flags.plusPaywallEnabled) } ?? .some(.interests)
        if let next { go(to: next) } else { finish() }
    }

    /// Skip on `route`, with the documented side effects.
    func skip(from route: OnboardingRoute) {
        switch route {
        case .interests: interests = []
        case .verification: verification = .skipped
        case .cover:
            coverStyle = .default
            pendingPlusCover = nil
            coverName = ""
        case .firstStamp, .passportReady, .plus: break
        }
        if route == .cover { continueFrom(.cover); return }
        guard let target = route.skipTarget else { return }
        go(to: target)
    }

    func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// The Offer sheet's "Continue with the free passport": the paywall was dismissed, and the passport opens.
    func finishFromOffer() {
        guard !isComplete else { return }
        plusOutcome = .dismissed
        finish()
    }

    /// A successful Plus purchase ends onboarding.
    func finishAfterPurchase() {
        guard !isComplete else { return }
        plusOutcome = .subscribed
        finish()
    }

    /// Completes onboarding once: a double tap or a second route into `finish` changes nothing.
    func finish() {
        guard completedAt == nil else { return }
        completedAt = now()
        persist()
        complete(appliedCover)
    }

    // MARK: Persistence

    private func go(to route: OnboardingRoute) {
        guard path.last != route else { return }
        path.append(route)
        let flow = OnboardingRoute.flow(plusEnabled: flags.plusPaywallEnabled)
        if let new = flow.firstIndex(of: route), new > (reached.flatMap(flow.firstIndex(of:)) ?? -1) { reached = route }
        persist()
    }

    private var progress: OnboardingProgress {
        OnboardingProgress(interests: interests, verification: verification, coverStyle: coverStyle, name: coverName,
                           reached: reached, completedAt: completedAt, passportIssuedAt: passportIssuedAt)
    }

    private func persist() {
        do {
            try repository.save(progress)
            lastSaveFailed = false
        } catch {
            lastSaveFailed = true
            log.error("Could not save onboarding progress: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func restore() {
        let saved: OnboardingProgress
        do { saved = try repository.load() } catch {
            log.error("Could not load onboarding progress: \(error.localizedDescription, privacy: .public)")
            return
        }
        interests = saved.interests
        verification = saved.verification
        coverStyle = saved.coverStyle
        coverName = saved.name
        reached = saved.reached
        completedAt = saved.completedAt
        passportIssuedAt = saved.passportIssuedAt
        path = saved.reached?.stack(plusEnabled: flags.plusPaywallEnabled) ?? []
        // Never re-collect: pick up a stamp the passport already holds.
        firstStamp = StampDestination.catalog.lazy.compactMap { self.collector.existing($0) }.first
    }
}
