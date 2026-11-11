import Foundation
import Observation
import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum MotionPreference: String, CaseIterable, Identifiable {
    /// Follow the system Reduce Motion setting.
    case system
    /// Always use the calm, reduced presentation.
    case reduced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Follow system")
        case .reduced: String(localized: "Always reduce")
        }
    }
}

/// The colour of the passport cover.
enum PassportStyle: String, CaseIterable, Identifiable {
    case terracotta, forest, ink, sky, rose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terracotta: String(localized: "Terracotta")
        case .forest: String(localized: "Forest")
        case .ink: String(localized: "Midnight")
        case .sky: String(localized: "Sky")
        case .rose: String(localized: "Rose")
        }
    }

    var color: Color {
        switch self {
        case .terracotta: Color(hex: 0xA95F3B)
        case .forest: Color(hex: 0x3F5A48)
        case .ink: Color(hex: 0x262B3A)
        case .sky: Color(hex: 0x4D7396)
        case .rose: Color(hex: 0x9C5560)
        }
    }

    /// Foil colour of the emblem and lettering on the cover.
    var foil: Color {
        switch self {
        case .ink: Color(hex: 0xE3C98A)
        default: Color(hex: 0xF0DFB4)
        }
    }
}

/// Small, genuine user preferences persisted in `UserDefaults`.
/// Personal travel data never lives here; that belongs in the SwiftData store.
@MainActor
@Observable
final class PreferencesStore {
    private let defaults: UserDefaults

    var appearance: AppearancePreference { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    var motion: MotionPreference { didSet { defaults.set(motion.rawValue, forKey: Key.motion) } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) } }
    var locationVerificationEnabled: Bool { didSet { defaults.set(locationVerificationEnabled, forKey: Key.locationVerification) } }
    var passportStyle: PassportStyle { didSet { defaults.set(passportStyle.rawValue, forKey: Key.passportStyle) } }
    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarded) } }
    /// Newest first, capped at `recentLimit`.
    private(set) var recentlyViewed: [String] { didSet { defaults.set(recentlyViewed, forKey: Key.recent) } }
    /// Terms the person searched for, newest first, capped at `recentSearchLimit`. On this device only; never exported.
    private(set) var recentSearches: [String] { didSet { defaults.set(recentSearches, forKey: Key.recentSearches) } }

    /// Memory search terms, newest first, at most `recentMemorySearchLimit`. On this device only; never exported.
    private(set) var recentMemorySearches: [String] { didSet { defaults.set(recentMemorySearches, forKey: Key.recentMemorySearches) } }

    /// Stamps whose postmark the person chose to hide ("Show on my stamp" off). A presentation choice, kept on this device.
    private(set) var hiddenPostmarks: Set<String> { didSet { defaults.set(Array(hiddenPostmarks).sorted(), forKey: Key.hiddenPostmarks) } }

    static let recentMemorySearchLimit = 5
    static let recentLimit = 10
    static let recentSearchLimit = 8

    private enum Key {
        static let appearance = "pref.appearance"
        static let motion = "pref.motion"
        static let haptics = "pref.haptics"
        static let locationVerification = "pref.locationVerification"
        static let passportStyle = "pref.passportStyle"
        static let onboarded = "pref.onboarded"
        static let recent = "pref.recentlyViewed"
        static let recentSearches = "pref.recentSearches"
        static let recentMemorySearches = "pref.recentMemorySearches"
        static let hiddenPostmarks = "pref.hiddenPostmarks"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppearancePreference(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        motion = MotionPreference(rawValue: defaults.string(forKey: Key.motion) ?? "") ?? .system
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        locationVerificationEnabled = defaults.object(forKey: Key.locationVerification) as? Bool ?? true
        passportStyle = PassportStyle(rawValue: defaults.string(forKey: Key.passportStyle) ?? "") ?? .terracotta
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)
        recentlyViewed = defaults.stringArray(forKey: Key.recent) ?? []
        recentSearches = defaults.stringArray(forKey: Key.recentSearches) ?? []
        recentMemorySearches = defaults.stringArray(forKey: Key.recentMemorySearches) ?? []
        hiddenPostmarks = Set(defaults.stringArray(forKey: Key.hiddenPostmarks) ?? [])
    }

    func isPostmarkHidden(_ stampID: String) -> Bool { hiddenPostmarks.contains(stampID) }

    func setPostmarkHidden(_ hidden: Bool, for stampID: String) {
        if hidden { hiddenPostmarks.insert(stampID) } else { hiddenPostmarks.remove(stampID) }
    }

    func noteViewed(_ destinationID: String) {
        var list = recentlyViewed.filter { $0 != destinationID }
        list.insert(destinationID, at: 0)
        recentlyViewed = Array(list.prefix(Self.recentLimit))
    }

    func clearRecentlyViewed() { recentlyViewed = [] }

    /// Puts a cleared list back exactly as it was (Undo).
    func restoreRecentlyViewed(_ list: [String]) { recentlyViewed = Array(list.prefix(Self.recentLimit)) }

    /// Adds a search term: trimmed, case-insensitive de-duplication, newest first.
    func noteSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(trimmed, at: 0)
        recentSearches = Array(list.prefix(Self.recentSearchLimit))
    }

    func noteMemorySearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = recentMemorySearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(trimmed, at: 0)
        recentMemorySearches = Array(list.prefix(Self.recentMemorySearchLimit))
    }

    func clearRecentMemorySearches() { recentMemorySearches = [] }
    func restoreRecentMemorySearches(_ list: [String]) { recentMemorySearches = Array(list.prefix(Self.recentMemorySearchLimit)) }

    func clearRecentSearches() { recentSearches = [] }
    func restoreRecentSearches(_ list: [String]) { recentSearches = Array(list.prefix(Self.recentSearchLimit)) }

    /// Restores every preference to its default (does not touch passport data).
    func resetToDefaults() {
        appearance = .system
        motion = .system
        hapticsEnabled = true
        locationVerificationEnabled = true
        passportStyle = .terracotta
        recentlyViewed = []
        recentSearches = []
        recentMemorySearches = []
        hiddenPostmarks = []
    }
}
