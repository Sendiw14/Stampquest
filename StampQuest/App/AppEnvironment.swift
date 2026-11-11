import Foundation
import Observation
import SwiftData
import SwiftUI

/// Everything the running app needs, wired once at launch.
@MainActor
@Observable
final class AppEnvironment {
    let catalog: Catalog
    let container: ModelContainer
    let store: PassportStore
    let preferences: PreferencesStore
    let router: AppRouter
    let haptics: HapticsService
    let verification: VerificationService
    let photos: PhotoStore
    /// Location permission and one-shot readings. Onboarding's verification screen requests When-In-Use through this.
    let location: LocationProviding
    let purchases: PurchaseService
    let reminders: ReminderService
    let subscriptions: SubscriptionClient
    let packs: PackStoreClient
    let exitSheetStore: ExitSheetStore
    let packManifest: [Pack]
    let parallax: ParallaxMotionProviding
    let onboarding: OnboardingModel
    /// The single toast of the app (Discover and Wishlist show it).
    let toasts = ToastCenter()

    init(catalog: Catalog, container: ModelContainer, preferences: PreferencesStore, locationProvider: LocationProviding,
         photos: PhotoStore, purchases: PurchaseService = UnavailablePurchaseService(),
         reminders: ReminderService = UnavailableReminderService(),
         subscriptions: SubscriptionClient = UnavailableSubscriptionClient(), packs: PackStoreClient = UnavailablePackStoreClient(),
         exitSheetStore: ExitSheetStore = UserDefaultsExitSheetStore(), packManifest: [Pack] = PackManifest.all, flags: FeatureFlags = .current,
         parallax: ParallaxMotionProviding = CoreMotionParallaxService()) {
        self.catalog = catalog
        self.container = container
        self.preferences = preferences
        self.photos = photos
        self.router = AppRouter()
        self.haptics = HapticsService(isEnabled: preferences.hapticsEnabled)
        let store = PassportStore(context: container.mainContext, catalog: catalog, photoFiles: photos)
        self.store = store
        self.verification = VerificationService(provider: locationProvider)
        self.location = locationProvider
        self.purchases = purchases
        self.reminders = reminders
        self.subscriptions = subscriptions
        self.packs = packs
        self.exitSheetStore = exitSheetStore
        self.packManifest = packManifest
        self.parallax = parallax
        self.onboarding = OnboardingModel(
            repository: SwiftDataOnboardingRepository(context: container.mainContext),
            collector: Self.collector(for: store), purchases: purchases, flags: flags,
            complete: { [preferences] cover in
                preferences.passportStyle = cover.passportStyle
                preferences.hasCompletedOnboarding = true
            })
        if onboarding.isComplete { preferences.hasCompletedOnboarding = true }
    }

    /// StoreKit and local notifications only when the paywall flag is on (the listener for transaction updates then runs
    /// from launch); a DEBUG launch argument swaps in deterministic fakes for UI tests.
    fileprivate static func plusServices(_ launch: LaunchConfiguration) -> (SubscriptionClient, ReminderService) {
        #if DEBUG
        if let scenario = launch.subscriptionScenario {
            let reminders = MockReminderService()
            reminders.isAuthorized = launch.notificationsAuthorized ?? false
            return (FakeSubscriptionClient.scenario(scenario), reminders)
        }
        #endif
        guard FeatureFlags.current.plusPaywallEnabled else { return (UnavailableSubscriptionClient(), UnavailableReminderService()) }
        return (StoreKitSubscriptionClient(), LiveReminderService())
    }

    /// The pack client: StoreKit when the Coasts pack flag is on, a DEBUG fake for UI tests, otherwise nothing is offered.
    fileprivate static func packClient(_ launch: LaunchConfiguration) -> PackStoreClient {
        #if DEBUG
        if let scenario = launch.packScenario { return FakePackStoreClient.scenario(scenario) }
        #endif
        return FeatureFlags.current.coastsPackEnabled ? StoreKitPackStoreClient() : UnavailablePackStoreClient()
    }

    /// Collects onboarding stamps through the passport; a DEBUG launch argument makes the first save fail.
    private static func collector(for store: PassportStore) -> StampCollecting {
        let collector = CollectStampUseCase(store: store)
        #if DEBUG
        if LaunchConfiguration.current.simulateCollectFailure { return FailingOnceCollector(wrapping: collector) }
        #endif
        return collector
    }

    /// Effective reduced-motion state: the system setting, or the user's own override.
    func reducesMotion(system: Bool) -> Bool { system || preferences.motion == .reduced }
}

struct StartupFailure {
    enum Kind { case catalog, store }
    let kind: Kind
    let message: String
}

/// Creates the environment and, if something cannot be opened, exposes a recovery state
/// instead of crashing or silently discarding the person's data.
@MainActor
@Observable
final class AppBootstrap {
    enum State {
        case ready(AppEnvironment)
        case failed(StartupFailure)
    }

    private(set) var state: State

    init() {
        state = Self.attempt()
    }

    func retry() { state = Self.attempt() }

    /// Moves the unreadable store aside (never deleting it) and starts a fresh passport.
    func startFresh() {
        do {
            try PersistenceController.moveStoreToBackup()
            state = Self.attempt()
        } catch {
            state = .failed(StartupFailure(kind: .store, message: String(localized: "The old data couldn’t be moved aside. Nothing has been deleted.")))
        }
    }

    private static func attempt() -> State {
        let launch = LaunchConfiguration.current
        let defaults = UserDefaults.standard

        if launch.resetData {
            PersistenceController.eraseStoreFiles()
            try? FileManager.default.removeItem(at: StoragePaths.photosDirectory)
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("pref.") { defaults.removeObject(forKey: key) }
            defaults.removeObject(forKey: UserDefaultsExitSheetStore.key)
            defaults.removeObject(forKey: OnboardingModel.plusOfferShownKey)
            HomeViewModel.eraseStoredState(defaults)
            PassportViewModel.eraseStoredState(defaults)
        }

        let catalog: Catalog
        do { catalog = try CatalogLoader.load() } catch {
            return .failed(StartupFailure(kind: .catalog, message: error.localizedDescription))
        }

        let container: ModelContainer
        do { container = try PersistenceController.makeContainer(inMemory: launch.inMemoryStore) } catch {
            return .failed(StartupFailure(kind: .store, message: error.localizedDescription))
        }

        let preferences = PreferencesStore(defaults: defaults)
        if launch.skipOnboarding { preferences.hasCompletedOnboarding = true }
        if launch.reduceMotion { preferences.motion = .reduced }

        let provider: LocationProviding
        #if DEBUG
        if let script = launch.scriptedLocation { provider = ScriptedLocationProvider(script: script) } else { provider = CoreLocationProvider() }
        #else
        provider = CoreLocationProvider()
        #endif

        let (subscriptions, reminders) = AppEnvironment.plusServices(launch)
        let exitStore = UserDefaultsExitSheetStore()
        var manifest = PackManifest.all
        #if DEBUG
        if launch.exitSheetShown { exitStore.markShown() }
        if launch.packArtReady { manifest = manifest.map { Pack(id: $0.id, interest: $0.interest, subjectKey: $0.subjectKey, stamps: $0.stamps, hasRealArt: true) } }
        #endif
        let environment = AppEnvironment(catalog: catalog, container: container, preferences: preferences,
                                         locationProvider: provider, photos: PhotoStore(), reminders: reminders,
                                         subscriptions: subscriptions, packs: AppEnvironment.packClient(launch),
                                         exitSheetStore: exitStore, packManifest: manifest)
        #if DEBUG
        if let seed = launch.seed { DebugSeeder.seed(seed, into: environment) }
        if let url = launch.openURL { environment.router.open(url, catalog: catalog) }
        if let start = launch.onboardingStart, let index = OnboardingRoute.allCases.firstIndex(of: start) {
            environment.onboarding.path = Array(OnboardingRoute.allCases.prefix(through: index))
        }
        #endif
        return .ready(environment)
    }
}
