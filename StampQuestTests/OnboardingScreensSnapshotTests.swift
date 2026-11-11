import Testing
import SwiftUI
import UIKit
@testable import StampQuest

/// Renders each onboarding screen through the real flow view at 402 x 874 in light and dark (a hosting controller honours the appearance even
/// where the simulator does not) and keeps the images under `StampQuestTests/Snapshots` as layout baselines. Reduced motion shows the rest state.
@MainActor
@Suite(.serialized)
struct OnboardingScreensSnapshotTests {
    enum Screen: String, CaseIterable {
        case welcome, interests, firstStamp, verification, cover, passportReady

        var route: OnboardingRoute? { OnboardingRoute(rawValue: rawValue) }
    }

    static let size = CGSize(width: 402, height: 874)

    func makeEnvironment() throws -> AppEnvironment {
        let defaults = UserDefaults(suiteName: "onboarding-snapshots-\(UUID().uuidString)") ?? .standard
        let preferences = PreferencesStore(defaults: defaults)
        preferences.motion = .reduced
        return AppEnvironment(catalog: try CatalogLoader.load(), container: try PersistenceController.makeContainer(inMemory: true),
                              preferences: preferences, locationProvider: MockLocationProvider(), photos: PhotoStore(),
                              flags: FeatureFlags(plusPaywallEnabled: true, coastsPackEnabled: true))
    }

    @Test(arguments: Screen.allCases, [false, true])
    func snapshot(screen: Screen, dark: Bool) async throws {
        let env = try makeEnvironment()
        if let route = screen.route, let index = OnboardingRoute.allCases.firstIndex(of: route) {
            env.onboarding.path = Array(OnboardingRoute.allCases.prefix(through: index))
        }
        let view = OnboardingFlowView().environment(env)
        let image = try await SnapshotSupport.image(of: view, size: Self.size, dark: dark)
        try SnapshotSupport.verify(image, named: "onboarding-\(screen.rawValue)-\(dark ? "dark" : "light")", size: Self.size)
    }
}
