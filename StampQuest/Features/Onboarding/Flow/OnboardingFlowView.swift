import SwiftUI

/// Root of onboarding: a `NavigationStack` over `OnboardingRoute` with a custom top bar. The system back button is
/// hidden but the swipe-back gesture keeps working (`SwipeBackBridge`).
struct OnboardingFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        @Bindable var model = env.onboarding
        NavigationStack(path: $model.path) {
            WelcomeView(model: model)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    OnboardingRouteView(route: route, model: model)
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                        .background(SwipeBackBridge())
                }
        }
        .environment(\.obReducesMotion, env.reducesMotion(system: systemReduceMotion))
        .environment(\.obHapticsEnabled, env.preferences.hapticsEnabled)
        .tint(OBColor.accent)
        .accessibilityIdentifier("onboarding")
    }
}

/// Resolves a route to its screen. Every screen after Welcome is a placeholder until its own prompt lands.
struct OnboardingRouteView: View {
    @Environment(AppEnvironment.self) private var env
    let route: OnboardingRoute
    let model: OnboardingModel

    var body: some View {
        switch route {
        case .interests: InterestsScreen(model: model)
        case .firstStamp: FirstStampScreen(model: model)
        case .verification: VerificationView(model: model, location: env.location)
        case .cover: CoverView(model: model)
        case .passportReady: PassportReadyView(model: model, location: env.location)
        case .plus: PlusPaywallView(model: model, client: env.subscriptions, reminders: env.reminders, packs: env.packs, manifest: env.packManifest, exitStore: env.exitSheetStore)
        }
    }
}
