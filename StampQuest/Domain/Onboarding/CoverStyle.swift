import Foundation

/// The five passport covers (onboarding prompt 05), in carousel order. Midnight and Rosewood are Plus covers: shown
/// only when `FeatureFlags.plusPaywallEnabled` is on, and never a gate on the passport itself.
nonisolated enum CoverStyle: String, CaseIterable, Codable, Hashable, Sendable {
    case clay, forest, midnight, harbor, rosewood

    static let `default`: CoverStyle = .harbor

    var isPlus: Bool { self == .midnight || self == .rosewood }

    /// Light, base and deep colours of the cover gradient (24-bit RGB).
    var colors: (hi: UInt32, base: UInt32, deep: UInt32) {
        switch self {
        case .clay: (0xB76E49, 0xA95F3B, 0x8F4E2F)
        case .forest: (0x4A6853, 0x3F5A48, 0x324A3A)
        case .midnight: (0x30364A, 0x262B3A, 0x1C2029)
        case .harbor: (0x5B83A8, 0x4D7396, 0x3F6080)
        case .rosewood: (0xAB636E, 0x9C5560, 0x834550)
        }
    }

    /// The covers shown: all five when the paywall is on, otherwise only the three free ones.
    static func available(plusEnabled: Bool) -> [CoverStyle] {
        plusEnabled ? allCases : allCases.filter { !$0.isPlus }
    }

    static var free: [CoverStyle] { allCases.filter { !$0.isPlus } }

    var nameKey: String { "onboarding.cover.style." + rawValue }
}
