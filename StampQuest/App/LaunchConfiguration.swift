import Foundation

/// Test and development switches read from launch arguments.
///
/// These exist only in DEBUG builds. In Release the arguments are ignored entirely, so
/// shipped builds can never be put into a fake-data or fake-location mode.
struct LaunchConfiguration {
    enum Seed: String { case few, many, islandAlmost, memories }

    /// Erase the on-disk store, photos and preferences before starting.
    var resetData = false
    var skipOnboarding = false
    /// Opens onboarding on this step, with Welcome underneath, instead of at Welcome.
    var onboardingStart: OnboardingRoute?
    /// The first attempt to collect the onboarding stamp fails (the next one works), to exercise the error and "Try again".
    var simulateCollectFailure = false
    /// Forces the app's own "always reduce motion" preference, so UI tests run without animations.
    var reduceMotion = false
    var inMemoryStore = false
    var seed: Seed?
    /// Scripted device location (see `ScriptedLocationProvider`).
    var scriptedLocation: String?
    var showsArtGallery = false
    /// A `stampquest://` URL to open right after launch (exercises deep links).
    var openURL: URL?
    /// Replaces the StoreKit client with `FakeSubscriptionClient.scenario(_:)`.
    var subscriptionScenario: String?
    /// Replaces the notification centre with a mock that is, or is not, already authorized.
    var notificationsAuthorized: Bool?
    /// Replaces the StoreKit pack client with `FakePackStoreClient.scenario(_:)`.
    var packScenario: String?
    /// Starts with the exit sheet already marked as shown.
    var exitSheetShown = false
    /// Treats every pack as having real art, so the exit sheet shows its pack row.
    var packArtReady = false
    /// The first attempt to open the search index fails (the next one works), to exercise the Search error state.
    var searchFailsOnce = false
    /// The first collect from Stamp detail fails (the retry works), to exercise the collect-failed alert.
    var stampCollectFailsOnce = false
    /// The first removal from Stamp detail fails, to exercise the remove-failed alert.
    var stampRemoveFailsOnce = false
    /// Starts the Map on its "map unavailable" state, since tile failures cannot be forced from a test.
    var mapUnavailable = false

    static let current: LaunchConfiguration = {
        #if DEBUG
        return LaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        #else
        return LaunchConfiguration()
        #endif
    }()

    init() {}

    #if DEBUG
    init(arguments: [String]) {
        resetData = arguments.contains("-uitest-reset")
        skipOnboarding = arguments.contains("-uitest-skip-onboarding")
        reduceMotion = arguments.contains("-uitest-reduce-motion")
        simulateCollectFailure = arguments.contains("-simulateCollectFailure")
        if let i = arguments.firstIndex(of: "-uitest-onboarding-start"), arguments.indices.contains(i + 1) {
            onboardingStart = OnboardingRoute(rawValue: arguments[i + 1])
        }
        inMemoryStore = arguments.contains("-uitest-in-memory")
        showsArtGallery = arguments.contains("-art-gallery")
        if let i = arguments.firstIndex(of: "-uitest-seed"), arguments.indices.contains(i + 1) {
            seed = Seed(rawValue: arguments[i + 1])
        }
        if let i = arguments.firstIndex(of: "-uitest-location"), arguments.indices.contains(i + 1) {
            scriptedLocation = arguments[i + 1]
        }
        if let i = arguments.firstIndex(of: "-uitest-subscriptions"), arguments.indices.contains(i + 1) {
            subscriptionScenario = arguments[i + 1]
        }
        if let i = arguments.firstIndex(of: "-uitest-packs"), arguments.indices.contains(i + 1) { packScenario = arguments[i + 1] }
        exitSheetShown = arguments.contains("-uitest-exit-shown")
        packArtReady = arguments.contains("-uitest-pack-art")
        searchFailsOnce = arguments.contains("-uitest-search-error")
        stampCollectFailsOnce = arguments.contains("-uitest-stamp-collect-fails-once")
        stampRemoveFailsOnce = arguments.contains("-uitest-stamp-remove-fails-once")
        mapUnavailable = arguments.contains("-uitest-map-unavailable")
        if let i = arguments.firstIndex(of: "-uitest-notifications"), arguments.indices.contains(i + 1) {
            notificationsAuthorized = arguments[i + 1] == "authorized"
        }
        if let i = arguments.firstIndex(of: "-uitest-url"), arguments.indices.contains(i + 1) {
            openURL = URL(string: arguments[i + 1])
        }
    }
    #endif
}
