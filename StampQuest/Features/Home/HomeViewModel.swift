import Foundation
import Observation

/// The state Home keeps beyond the records: the local-day swap override, the Collect button state and Near you.
@MainActor
@Observable
final class HomeViewModel {
    enum CollectState: Equatable { case idle, saving, failed }

    private(set) var collectState = CollectState.idle
    private(set) var nearby: HomeNearby?
    private(set) var dayOverride: String?

    private let env: AppEnvironment
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var lastLocationRead: Date?
    private var isReadingLocation = false

    private enum Key {
        static let install = "home.installID"
        static let overrideID = "home.override.id"
        static let overrideDay = "home.override.day"
    }

    init(env: AppEnvironment, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.env = env
        self.defaults = defaults
        self.calendar = calendar
        dayOverride = Self.storedOverride(defaults, today: HomeFeaturedPicker.dayNumber(.now, calendar: calendar))
    }

    /// For `-uitest-reset`: forget the install id and the day override.
    static func eraseStoredState(_ defaults: UserDefaults) {
        for key in [Key.install, Key.overrideID, Key.overrideDay] { defaults.removeObject(forKey: key) }
    }

    static func storedOverride(_ defaults: UserDefaults, today: Int) -> String? {
        guard defaults.object(forKey: Key.overrideDay) as? Int == today else { return nil }
        return defaults.string(forKey: Key.overrideID)
    }

    /// Created on first use and kept; it only seeds the daily order, so it never leaves the device.
    var installID: String {
        if let id = defaults.string(forKey: Key.install) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Key.install)
        return id
    }

    func snapshot(passport: PassportContext, memory: HomeMemory?, now: Date = .now) -> HomeSnapshot {
        HomeSnapshotBuilder.build(catalog: passport.catalog, snapshot: passport.snapshot, memory: memory, nearby: nearby,
                                  installID: installID, now: now, calendar: calendar, dayOverride: dayOverride)
    }

    // MARK: Actions

    /// Swaps the featured and side stamps for the rest of the local day.
    func swapFeatured(to id: String) {
        dayOverride = id
        defaults.set(id, forKey: Key.overrideID)
        defaults.set(HomeFeaturedPicker.dayNumber(.now, calendar: calendar), forKey: Key.overrideDay)
        env.haptics.selection()
    }

    /// Persists the stamp by hand. The reveal and the success feedback follow only a successful save.
    func collect(_ destinationID: String) {
        guard collectState != .saving else { return }
        collectState = .saving
        if env.collect(destinationID) == nil {
            collectState = .idle
            clearOverride()
        } else {
            collectState = .failed
        }
    }

    func dismissError() { collectState = .idle }

    private func clearOverride() {
        dayOverride = nil
        defaults.removeObject(forKey: Key.overrideID)
        defaults.removeObject(forKey: Key.overrideDay)
    }

    /// One fix per appearance, at most one every 10 minutes, and never a permission prompt.
    func refreshNearby(passport: PassportContext, now: Date = .now) async {
        guard !isReadingLocation, !passport.snapshot.stamps.isEmpty else { nearby = nil; return }
        let enabled = await env.location.servicesEnabled()
        guard HomeNearbyFinder.mayRead(authorization: env.location.authorization, servicesEnabled: enabled,
                                       lastRead: lastLocationRead, now: now) else {
            if env.location.authorization != .authorized { nearby = nil }
            return
        }
        isReadingLocation = true
        defer { isReadingLocation = false }
        lastLocationRead = now
        guard let reading = try? await env.location.currentReading(timeout: .seconds(4)) else { nearby = nil; return }
        let collected = Set(passport.snapshot.stamps.map(\.destinationID))
        nearby = HomeNearbyFinder.nearest(reading: reading, catalog: passport.catalog, collectedIDs: collected, now: .now)
    }
}
