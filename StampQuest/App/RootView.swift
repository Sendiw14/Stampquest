import SwiftUI
import SwiftData
import CoreSpotlight

struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.preferences.hasCompletedOnboarding {
                PassportProvider { MainTabView() }
            } else {
                PassportProvider { OnboardingFlowView() }
            }
        }
        .preferredColorScheme(env.preferences.appearance.colorScheme)
        .tint(SQColor.accentText)
        .onOpenURL { url in env.router.open(url, catalog: env.catalog) }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = SpotlightIndexer.destinationID(from: activity), let url = URL(string: "stampquest://destination/\(id)") {
                env.router.open(url, catalog: env.catalog)
            }
        }
        .onChange(of: NavigationInbox.shared.pending, initial: true) { _, url in
            guard let url else { return }
            env.router.open(url, catalog: env.catalog)
            NavigationInbox.shared.pending = nil
        }
        .task { await SpotlightIndexer.indexIfNeeded(catalog: env.catalog) }
        .onChange(of: env.preferences.hapticsEnabled, initial: true) { _, enabled in env.haptics.isEnabled = enabled }
    }
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var router = env.router
        TabView(selection: Binding(get: { env.router.selectedTab }, set: { env.router.select($0) })) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: env.router.binding(for: tab)) {
                    root(for: tab)
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
                .tabItem { Label(tab.title, systemImage: tab.symbolName) }
                .tag(tab)
            }
        }
        .fullScreenCover(item: $router.reveal) { payload in
            RevealView(payload: payload)
        }
    }

    @ViewBuilder
    private func root(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .passport: PassportView()
        case .discover: DiscoverView()
        case .map: MapTabView()
        case .memories: MemoriesView()
        }
    }
}

/// Resolves a typed route to its screen.
struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .destination(let id): DestinationDetailView(destinationID: id)
        case .stamp(let id): StampDetailView(destinationID: id)
        case .collection(let id): CollectionDetailView(collectionID: id)
        case .collections: CollectionsView()
        case .wishlist: WishlistView()
        case .statistics: StatisticsView()
        case .achievements: AchievementsView()
        case .trips: TripsView()
        case .trip(let id): TripDetailView(tripID: id)
        case .memory(let id): MemoryDetailView(memoryID: id)
        case .settings: SettingsView()
        case .category(let category): DiscoverResultsView(spec: .category(category))
        case .interests: AllInterestsView()
        case .discoverResults(let spec): DiscoverResultsView(spec: spec)
        case .country(let code): CountryResultsView(countryCode: code)
        }
    }
}

/// Shown when the catalog or the on-device store cannot be opened. Never deletes data.
struct StartupFailureView: View {
    let failure: StartupFailure
    let retry: () -> Void
    let startFresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: SQSpace.lg) {
                Image(systemName: failure.kind == .store ? "externaldrive.badge.exclamationmark" : "exclamationmark.triangle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(SQColor.accent)
                    .padding(.top, SQSpace.xxl)
                    .accessibilityHidden(true)
                Text(failure.kind == .store ? "Your passport couldn’t be opened" : "The catalog couldn’t be loaded")
                    .font(SQFont.title)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SQColor.textPrimary)
                Text(failure.message)
                    .font(SQFont.body)
                    .foregroundStyle(SQColor.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Try again", systemImage: "arrow.clockwise", action: retry)
                if failure.kind == .store {
                    VStack(spacing: SQSpace.xs) {
                        SecondaryActionButton(title: "Back up and start a new passport", systemImage: "archivebox", action: startFresh)
                        Text("Your existing data is moved to a backup folder on this device, not deleted.")
                            .font(SQFont.caption)
                            .foregroundStyle(SQColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(SQSpace.screenMargin)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .sqScreenBackground()
    }
}
