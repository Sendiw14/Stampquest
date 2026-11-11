import Foundation

/// Remembers that the exit sheet was shown. It is shown at most once, ever.
@MainActor
protocol ExitSheetStore: AnyObject {
    var isShown: Bool { get }
    func markShown()
}

@MainActor
final class UserDefaultsExitSheetStore: ExitSheetStore {
    static let key = "onboarding.exitSheetShown"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isShown: Bool { defaults.bool(forKey: Self.key) }
    func markShown() { defaults.set(true, forKey: Self.key) }
}

@MainActor
final class InMemoryExitSheetStore: ExitSheetStore {
    private(set) var isShown: Bool

    init(isShown: Bool = false) { self.isShown = isShown }
    func markShown() { isShown = true }
}

/// When closing the Plus paywall opens the exit sheet. Pure.
nonisolated enum ExitSheetPolicy {
    /// Only with the paywall flag on, without Plus, and if the sheet has not been shown before; otherwise Close goes straight to finish.
    static func shouldPresent(plusEnabled: Bool, isEntitled: Bool, alreadyShown: Bool) -> Bool {
        plusEnabled && !isEntitled && !alreadyShown
    }
}
