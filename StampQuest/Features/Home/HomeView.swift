import SwiftUI
import SwiftData

/// The Home tab (Design Z2 "Window"): the hero and Today card first, then the modules that have something real to show.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View { HomeContent(env: env) }
}

struct HomeContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Query(sort: [SortDescriptor(\MemoryEntry.createdAt, order: .reverse)]) private var memories: [MemoryEntry]
    @Query private var profiles: [PassportProfile]
    @State private var model: HomeViewModel
    @State private var offset: CGFloat = 0
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    init(env: AppEnvironment) { _model = State(initialValue: HomeViewModel(env: env)) }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var memory: HomeMemory? {
        memories.first.map { HomeMemory(id: $0.id, title: $0.title, text: $0.text, eventDate: $0.eventDate, destinationID: $0.destinationID, photoCount: $0.photoFilenames.count) }
    }
    private var name: String { profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }

    var body: some View {
        let home = model.snapshot(passport: passport, memory: memory)
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let width = proxy.size.width
            let scale = min(1.10, max(0.93, min(width, 560) / 402))
            ScrollView {
                VStack(spacing: 0) {
                    ScrollOffsetAnchor(space: "homeScroll")
                    hero(home, safeTop: safeTop, width: width, scale: scale)
                    modules(home).frame(maxWidth: 560).padding(.horizontal, 20).padding(.top, 90).padding(.bottom, 40).frame(maxWidth: .infinity)
                }
            }
            .modifier(ScrollOffsetReader(offset: $offset, space: "homeScroll"))
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .top) { collapsedBar(home) }
        }
        .background(HomeColor.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.refreshNearby(passport: passport) }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        .accessibilityIdentifier("home-screen")
    }

    // MARK: Hero

    private func hero(_ home: HomeSnapshot, safeTop: CGFloat, width: CGFloat, scale: CGFloat) -> some View {
        let featured = home.featuredID.flatMap(passport.item(id:))
        let side = home.sideID.flatMap(passport.item(id:))
        let height = safeTop + HomeHeroView.canvas.height * scale
        let drifts = !reduceMotion && !lowPower && scenePhase == .active && offset < height
        return ZStack(alignment: .top) {
            PosterBackground().frame(width: width, height: height)
            HomeHeroView(home: home, featured: featured, side: side, name: name, cover: env.preferences.passportStyle, drifts: drifts,
                         onSettings: { env.router.push(.settings) }, onSearch: { env.router.select(.discover) }, onSwap: { swap(side) })
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: HomeHeroView.canvas.width * scale, height: HomeHeroView.canvas.height * scale, alignment: .topLeading)
                .padding(.top, safeTop)
            if let featured {
                TodayCardView(item: featured, isFirstRun: home.isFirstRun, state: model.collectState, now: .now,
                              onOpen: { env.router.push(.destination(featured.id)) }, onCollect: { model.collect(featured.id) },
                              onRetry: { model.collect(featured.id) })
                    .frame(maxWidth: 560 - 28).padding(.horizontal, 14)
                    .frame(maxHeight: .infinity, alignment: .bottom).offset(y: 58)
            }
        }
        .frame(width: width, height: height)
        .zIndex(1)
    }

    private func swap(_ side: DestinationItem?) {
        guard let side else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.8)) { model.swapFeatured(to: side.id) }
    }

    // MARK: Collapsed bar

    @ViewBuilder
    private func collapsedBar(_ home: HomeSnapshot) -> some View {
        let progress = min(1, max(0, (offset - 110) / 60))
        HStack(spacing: 12) {
            PassportBookView(style: env.preferences.passportStyle, width: 28).frame(width: 28, height: 38).clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(name.isEmpty ? String(localized: "StampQuest") : name).font(.system(size: 20, weight: .bold)).foregroundStyle(HomeColor.ink).lineLimit(1)
                if !home.isFirstRun {
                    Text("^[\(home.stampCount) stamp](inflect: true), ^[\(home.countryCount) country](inflect: true)").font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background { Rectangle().fill(.ultraThinMaterial).ignoresSafeArea(edges: .top) }
        .overlay(alignment: .bottom) { Rectangle().fill(HomeColor.cardLine.opacity(0.5)).frame(height: 1) }
        .opacity(progress).allowsHitTesting(progress > 0.9).accessibilityHidden(progress < 0.5)
    }

    // MARK: Modules

    @ViewBuilder
    private func modules(_ home: HomeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            let picks = home.pickIDs.compactMap(passport.item(id:))
            if !picks.isEmpty {
                HomeSectionHeader(title: "Picked for you", link: "See all", linkIdentifier: "home-picks-all") { env.router.select(.discover) }
                PicksRow(items: picks) { env.router.push(.destination($0)) }
            }
            if home.isFirstRun {
                ExploreAllButton { env.router.select(.discover) }
                HowItWorks()
            } else {
                finishTheSet(home)
                nearYou(home)
                atlas(home)
                lookBack(home)
            }
        }
    }

    @ViewBuilder
    private func finishTheSet(_ home: HomeSnapshot) -> some View {
        if !home.sets.isEmpty {
            HomeSectionHeader(title: "Finish the set", link: "All \(passport.catalog.collections.count)", linkIdentifier: "home-sets-all") { env.router.push(.collections) }
            ForEach(home.sets, id: \.progress.collection.id) { set in
                FinishTheSetRow(set: set, items: set.shownIDs.compactMap(passport.item(id:))) { env.router.push(.collection(set.progress.collection.id)) }
            }
        }
    }

    @ViewBuilder
    private func nearYou(_ home: HomeSnapshot) -> some View {
        if let near = home.nearby, let item = passport.item(id: near.destinationID) {
            NearYouTicket(item: item, nearby: near, isSaving: model.collectState == .saving) {
                if near.isCollected { env.router.push(.destination(item.id)) } else { model.collect(item.id) }
            }
        }
    }

    @ViewBuilder
    private func atlas(_ home: HomeSnapshot) -> some View {
        if home.showsAtlas {
            HomeSectionHeader(title: "Your atlas", link: "Open map", linkIdentifier: "home-atlas-link") { env.router.select(.map) }
            AtlasCard(stamps: passport.snapshot.stamps.compactMap { passport.catalog.destination(id: $0.destinationID) },
                      verified: home.verifiedDestinationIDs.compactMap { passport.catalog.destination(id: $0) },
                      countryCount: home.countryCount, verifiedCount: home.verifiedCount) { env.router.select(.map) }
        }
    }

    @ViewBuilder
    private func lookBack(_ home: HomeSnapshot) -> some View {
        if let memory = home.latestMemory {
            HomeSectionHeader(title: "Look back", link: "See all", linkIdentifier: "home-memories-all") { env.router.select(.memories) }
            LookBackPostcard(memory: memory, item: memory.destinationID.flatMap(passport.item(id:))) { env.router.push(.memory(memory.id)) }
        }
    }
}
