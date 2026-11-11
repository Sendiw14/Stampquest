import Foundation

/// Compile-time-safe switches. Both default OFF until the audience is validated.
/// When `plusPaywallEnabled` is off the flow ends at Passport ready and Plus covers are hidden.
nonisolated struct FeatureFlags: Equatable, Sendable {
    var plusPaywallEnabled = false
    var coastsPackEnabled = false

    init(plusPaywallEnabled: Bool = false, coastsPackEnabled: Bool = false) {
        self.plusPaywallEnabled = plusPaywallEnabled
        self.coastsPackEnabled = coastsPackEnabled
    }

    #if DEBUG
    /// DEBUG launch arguments: `-ff-plus` and `-ff-coasts`.
    init(arguments: [String]) {
        self.init(plusPaywallEnabled: arguments.contains("-ff-plus"), coastsPackEnabled: arguments.contains("-ff-coasts"))
    }
    #endif

    static let current: FeatureFlags = {
        #if DEBUG
        FeatureFlags(arguments: ProcessInfo.processInfo.arguments)
        #else
        FeatureFlags()
        #endif
    }()
}
