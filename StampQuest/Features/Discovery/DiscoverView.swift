import SwiftUI
import SwiftData

/// The Discover tab (Design K1 "Search Stage"): a terracotta poster with a fan of two stamps and one large glass search
/// ticket, then interests, the editor's pick, curated collections, recently viewed places and the wishlist entry.
struct DiscoverView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View { DiscoverContent(env: env) }
}

/// What has already played in this launch: the entrance runs on the first appearance only, not on every tab switch.
@MainActor
enum DiscoverSession {
    static var hasEntered = false
}

/// The scroll offset lives in its own object so only the glass bar re-renders while scrolling.
@MainActor
@Observable
final class DiscoverScrollState { var offset: CGFloat = 0 }

struct DiscoverContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Query private var profiles: [PassportProfile]
    @State private var model: DiscoverViewModel
    @State private var search: DiscoverSearchModel
    @State private var scroll = DiscoverScrollState()
    @State private var entered: Bool
    @State private var landed: Bool
    @State private var isSearching = false
    @State private var showFilters = false
    @State private var pendingFilter: DiscoverFilter?
    @State private var retry = 0

    init(env: AppEnvironment) {
        _model = State(initialValue: DiscoverViewModel(env: env))
        _search = State(initialValue: DiscoverSearchModel(catalog: env.catalog))
        _entered = State(initialValue: DiscoverSession.hasEntered)
        _landed = State(initialValue: DiscoverSession.hasEntered)
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var picks: Set<Interest> { Set(profiles.first?.interestRaws.compactMap(Interest.init(rawValue:)) ?? []) }

    var body: some View {
        let derived = DiscoverDerived.make(catalog: passport.catalog, snapshot: passport.snapshot, recentIDs: env.preferences.recentlyViewed, picks: picks)
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let content = min(proxy.size.width, 560)
            let s = min(1.10, max(0.93, content / 402))
            let extra = max(0, safeTop - 54)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        ScrollOffsetAnchor(space: "discoverScroll").id("top")
                        hero(derived, s: s, extra: extra)
                        sections(derived, content: content, s: s)
                            .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 130)
                }
                .modifier(ScrollOffsetReader(offset: Binding(get: { scroll.offset }, set: { scroll.offset = $0 }), space: "discoverScroll", limit: 260))
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .top) {
                    DiscoverChrome(scroll: scroll, barHeight: safeTop + 76, safeTop: safeTop, wishlistCount: derived.wishlist.count,
                                   onSearch: openSearch, onFilters: { showFilters = true }, onWishlist: { env.router.push(.wishlist) })
                }
                .onChange(of: env.router.tabReselect) { _, _ in
                    guard env.router.selectedTab == .discover, env.router.path(for: .discover).isEmpty else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { reader.scrollTo("top", anchor: .top) }
                }
            }
            .overlay {
                if isSearching {
                    DiscoverSearchView(model: search, viewModel: model, topInset: safeTop, onCancel: closeSearch)
                        .transition(.opacity)
                }
            }
        }
        .background(HomeColor.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(isSearching ? .hidden : .visible, for: .tabBar)
        .discoverToast(env.toasts, bottomInset: isSearching ? 24 : 96)
        .onAppear { runEntrance(); runMemoriesHandoff() }
        .onChange(of: MemoryNavigation.shared.pendingDiscoverQuery) { _, _ in runMemoriesHandoff() }
        .sheet(isPresented: $showFilters, onDismiss: pushPendingResults) {
            DiscoverFiltersSheet(initial: DiscoverFilter(), matchCount: { filter in
                DiscoverResults.matches(scope: .places, filter: filter, catalog: passport.catalog, state: passport.snapshot.state(of:)).count
            }, countries: passport.catalog.countries.map { ($0.code, $0.name) },
               regions: Region.allCases.filter { region in passport.catalog.destinations.contains { $0.region == region } },
               categories: DestinationCategory.allCases.filter { category in passport.catalog.destinations.contains { $0.category == category } },
               onApply: { pendingFilter = $0; showFilters = false })
                .presentationDetents([.medium, .large], selection: .constant(.large))
                .presentationDragIndicator(.visible).presentationCornerRadius(36)
        }
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }

    // MARK: Entrance, search

    private func runEntrance() {
        guard !DiscoverSession.hasEntered else { return }
        DiscoverSession.hasEntered = true
        entered = true
        landed = true
    }

    private func openSearch() {
        search.prepare()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35)) { isSearching = true }
    }

    /// "Search places for ..." in Memories: opens Search here with that term. Only the term arrives, never memory text.
    private func runMemoriesHandoff() {
        guard let term = MemoryNavigation.shared.pendingDiscoverQuery else { return }
        MemoryNavigation.shared.pendingDiscoverQuery = nil
        search.prepare()
        isSearching = true
        search.run(term: term)
        model.noteSearch(term)
    }

    private func closeSearch() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35)) { isSearching = false }
        search.clear()
    }

    private func pushPendingResults() {
        guard let filter = pendingFilter else { return }
        pendingFilter = nil
        env.router.push(.discoverResults(DiscoverResultsSpec(scope: .places, filter: filter)))
    }

    // MARK: Hero

    private func hero(_ derived: DiscoverDerived, s: CGFloat, extra: CGFloat) -> some View {
        VStack(spacing: 0) {
            DiscoverHeroView(scale: s, topExtra: extra, placesToCollect: derived.placesToCollect.count, wishlistCount: derived.wishlist.count,
                             fan: derived.fanIDs.compactMap(passport.item(id:)), entered: entered, onWishlist: { env.router.push(.wishlist) })
            DiscoverTicketView(scale: s, onSearch: openSearch, onFilters: { showFilters = true })
                .frame(maxWidth: 560 - 28 * s).padding(.horizontal, 14 * s).frame(maxWidth: .infinity)
                .padding(.top, -62 * s)
                .offset(y: entered || reduceMotion ? 0 : 60).opacity(entered ? 1 : 0)
                .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.65, dampingFraction: 0.85).delay(0.12), value: entered)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func sections(_ derived: DiscoverDerived, content: CGFloat, s: CGFloat) -> some View {
        if passport.catalog.destinations.isEmpty {
            InlineErrorView(title: "Discover isn’t available right now", message: String(localized: "The place catalog couldn’t be loaded."), retry: { retry += 1 })
                .padding(.horizontal, 20).padding(.top, 28).accessibilityIdentifier("discover-catalog-error")
        } else {
            VStack(alignment: .leading, spacing: 30) {
                interests(derived, s: s)
                editorsPick(derived, s: s)
                collections(derived, s: s)
                recents(derived, s: s)
                DiscoverWishlistRow(items: derived.wishlist.prefix(2).compactMap { passport.item(id: $0.destinationID) }, count: derived.wishlist.count) { env.router.push(.wishlist) }
                    .padding(.horizontal, 20)
                DiscoverEditorNote().padding(.horizontal, 20)
            }
            .padding(.top, 30)
        }
    }

    @ViewBuilder
    private func interests(_ derived: DiscoverDerived, s: CGFloat) -> some View {
        if !derived.interests.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                PassportSectionHeader(title: "Browse by interest", identifier: "discover-interests-title", actionTitle: "See all",
                                      actionIdentifier: "discover-interests-all") { env.router.push(.interests) }
                    .padding(.horizontal, 20)
                DiscoverInterestRail(interests: derived.interests, art: { passport.item(id: $0.artDestinationID) }, scale: s, landed: landed) { interest in
                    env.router.push(.category(interest.category))
                }
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func editorsPick(_ derived: DiscoverDerived, s: CGFloat) -> some View {
        if let pick = derived.editorsPick, let item = passport.item(id: pick.id) {
            VStack(alignment: .leading, spacing: 0) {
                PassportSectionHeader(title: "Featured this week", identifier: "discover-featured-title").padding(.horizontal, 20)
                DiscoverEditorsPickCard(item: item, scale: s, onOpen: { env.router.push(.destination(item.id)) },
                                        onCollect: { model.collect(item.id) }, onToggleSave: { model.toggleWishlist(item.id) })
                    .padding(.horizontal, 20).padding(.top, 18)
            }
        }
    }

    @ViewBuilder
    private func collections(_ derived: DiscoverDerived, s: CGFloat) -> some View {
        if !derived.collections.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                PassportSectionHeader(title: "Curated collections", identifier: "discover-collections-title", actionTitle: "See all",
                                      actionIdentifier: "discover-collections-all") { env.router.push(.collections) }
                    .padding(.horizontal, 20)
                DiscoverCollectionRail(rows: derived.collections, items: coverItems(derived), scale: s) { env.router.push(.collection($0.collection.id)) }
                    .padding(.top, 12)
            }
        }
    }

    private func coverItems(_ derived: DiscoverDerived) -> [String: DestinationItem] {
        var items: [String: DestinationItem] = [:]
        for id in derived.collections.flatMap(\.coverIDs) where items[id] == nil { items[id] = passport.item(id: id) }
        return items
    }

    @ViewBuilder
    private func recents(_ derived: DiscoverDerived, s: CGFloat) -> some View {
        let items = derived.recents.compactMap(passport.item(id:))
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                PassportSectionHeader(title: "Continue exploring", identifier: "discover-recents-title", actionTitle: "Clear",
                                      actionIdentifier: "discover-recents-clear") { withAnimation { model.clearRecentlyViewed() } }
                    .padding(.horizontal, 20)
                DiscoverRecents(items: items, scale: s) { env.router.push(.destination($0.id)) }
                    .padding(.horizontal, 20).padding(.top, 20)
            }
        }
    }
}

/// The glass bar that takes over from the hero: title, wishlist, and the same search and filter controls as the ticket.
struct DiscoverChrome: View {
    let scroll: DiscoverScrollState
    let barHeight: CGFloat
    let safeTop: CGFloat
    let wishlistCount: Int
    let onSearch: () -> Void
    let onFilters: () -> Void
    let onWishlist: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var placeholderSize = 15.0

    var body: some View {
        // Starts to appear at about 170 pt of scroll and is fully there by about 240 pt. Not rendered at all before that, so an
        // invisible title is never in the accessibility tree.
        let opacity = min(1, max(0, (scroll.offset - 170) / 70))
        Group {
            if opacity > 0.01 { bar(opacity: opacity) }
        }
        .frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea(edges: .top)
    }

    private func bar(opacity: Double) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("Discover").font(.system(size: 20, weight: .bold)).tracking(-0.02 * 20).foregroundStyle(HomeColor.ink).accessibilityAddTraits(.isHeader)
                Spacer()
                DiscoverWishlistButton(count: wishlistCount, style: .bar, action: onWishlist).accessibilityIdentifier("discover-bar-wishlist")
            }
            .padding(.horizontal, 24).padding(.trailing, -4).frame(height: 36)
            .padding(.top, safeTop - 4)
            HStack(spacing: 8) {
                if typeSize.isAccessibilitySize { Spacer(minLength: 0); searchIconButton } else { pill }
                filterButton
            }
            .padding(.horizontal, 20).padding(.top, -2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity).frame(height: barHeight)
        .cardGlass(Rectangle(), tint: 0.90, lined: false)
        .overlay(alignment: .bottom) { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
        .opacity(opacity).allowsHitTesting(opacity > 0.6)
        .accessibilityHidden(opacity < 0.6)
    }

    private var pill: some View {
        Button(action: onSearch) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium)).foregroundStyle(HomeColor.sub).frame(width: 22)
                Text("Search places or landmarks").font(.system(size: placeholderSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 14).frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Search places or landmarks")).accessibilityHint(Text("Opens search")).accessibilityIdentifier("discover-bar-search")
    }

    private var searchIconButton: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.ink)
                .frame(width: 44, height: 44).background(PassportColor.quiet, in: Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(Text("Search places or landmarks")).accessibilityIdentifier("discover-bar-search")
    }

    private var filterButton: some View {
        Button(action: onFilters) {
            Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ctaText)
                .frame(width: 38, height: 38).background(HomeColor.cta, in: Circle())
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(Text("Filters")).accessibilityIdentifier("discover-bar-filters")
    }
}
