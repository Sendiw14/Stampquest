import SwiftUI
import SwiftData

/// The Passport tab (Design P1 "Cover Stage"): a terracotta poster with the cover tucked behind a ticket of four metrics,
/// then the collection as a grid, pages or a list.
struct PassportView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View { PassportContent(env: env) }
}

/// What has already played in this launch: the entrance runs on the first appearance only, not on every tab switch.
@MainActor
enum PassportSession {
    static var hasEntered = false
}

/// The scroll offset lives in its own object so only the views that read it (the title bar and the pinned controls)
/// re-render while scrolling, not the whole screen.
@MainActor
@Observable
final class PassportScrollState { var offset: CGFloat = 0 }

private enum ScrollTarget: Hashable { case top, grid, pages }

struct PassportContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Query private var profiles: [PassportProfile]
    @State private var model: PassportViewModel
    @State private var scroll = PassportScrollState()
    @State private var controlsTop: CGFloat = 0
    @State private var entered: Bool
    @State private var landed: Bool
    @State private var showFilter = false
    @State private var filterFocus: PassportFilterGroup?
    @State private var showShare = false
    @State private var showAdd = false
    @State private var pendingAdd: String?
    @State private var shareItem: DestinationItem?
    @State private var scrollTarget: ScrollTarget?

    init(env: AppEnvironment) {
        _model = State(initialValue: PassportViewModel(env: env))
        _entered = State(initialValue: PassportSession.hasEntered)
        _landed = State(initialValue: PassportSession.hasEntered)
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var profile: PassportProfile? { profiles.first }
    private var ownerName: String { profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    private var coverStyle: CoverStyle { profile.flatMap { CoverStyle(rawValue: $0.coverStyleRaw) } ?? .default }

    var body: some View {
        let derived = PassportDerived.make(snapshot: passport.snapshot, catalog: passport.catalog, query: model.query)
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let content = min(proxy.size.width, 560)
            let s = min(1.10, max(0.93, content / 402))
            let extra = max(0, safeTop - 54)
            let barHeight = safeTop + 52
            let pinY = barHeight + 10
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        ScrollOffsetAnchor(space: "passportScroll").id(ScrollTarget.top)
                        hero(derived, s: s, extra: extra)
                        Group {
                            if derived.isEmpty { emptyBody(content: content, s: s) } else { populated(derived, content: content, s: s) }
                        }
                        .frame(maxWidth: 560).frame(maxWidth: .infinity)
                        .transition(.opacity)
                    }
                    .coordinateSpace(name: "passportContent")
                    .padding(.bottom, 120)
                }
                .modifier(ScrollOffsetReader(offset: Binding(get: { scroll.offset }, set: { scroll.offset = $0 }), space: "passportScroll",
                                             limit: max(controlsTop - pinY, 200) + 1))
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .top) {
                    PassportChrome(scroll: scroll, model: model, barHeight: barHeight, pinY: pinY, controlsTop: controlsTop, content: content,
                                   isEmpty: derived.isEmpty, metrics: derived.metrics, coverStyle: coverStyle,
                                   onOpenFilter: { openFilter(nil) })
                }
                .overlay(alignment: .bottom) { undoToast }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                        switch target {
                        case .top: reader.scrollTo(ScrollTarget.top, anchor: .top)
                        case .grid, .pages: reader.scrollTo(target, anchor: UnitPoint(x: 0.5, y: 0.24))
                        }
                    }
                    scrollTarget = nil
                }
                .onChange(of: env.router.tabReselect) { _, _ in
                    if env.router.selectedTab == .passport, env.router.path(for: .passport).isEmpty { scrollTarget = .top }
                }
            }
        }
        .background(HomeColor.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.4), value: derived.isEmpty)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: derived.visible.map(\.id))
        .onAppear { runEntrance() }
        .sheet(isPresented: $showFilter) {
            PassportFilterSheet(model: model, countries: PassportDerived.countries(in: derived.all),
                                   collections: PassportDerived.collections(in: derived.all, catalog: passport.catalog),
                                   matchCount: derived.visible.count, focus: filterFocus) { showFilter = false }
                .presentationDetents([.medium, .large], selection: .constant(.large))
                .presentationDragIndicator(.visible).presentationCornerRadius(36)
        }
        .sheet(isPresented: $showShare) { SharePassportPageSheet(ownerName: ownerName) }
        .sheet(item: $shareItem) { ShareStampSheet(item: $0) }
        .sheet(isPresented: $showAdd, onDismiss: collectPending) { AddStampByHandSheet { pendingAdd = $0 } }
        .confirmationDialog("Remove \(model.pendingRemoval?.name ?? "") from your passport?",
                            isPresented: Binding(get: { model.pendingRemoval != nil }, set: { if !$0 { model.pendingRemoval = nil } }),
                            titleVisibility: .visible) {
            Button("Remove stamp", role: .destructive) { model.confirmRemoval() }
            Button("Cancel", role: .cancel) { model.pendingRemoval = nil }
        } message: { Text("Your memories about this place stay. You can collect the stamp again any time.") }
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }

    // MARK: Entrance

    private func runEntrance() {
        guard !PassportSession.hasEntered else { return }
        PassportSession.hasEntered = true
        entered = true
        landed = true
    }

    // MARK: Hero

    private func hero(_ derived: PassportDerived, s: CGFloat, extra: CGFloat) -> some View {
        VStack(spacing: 0) {
            PassportHeroView(scale: s, topExtra: extra, metrics: derived.metrics, isEmpty: derived.isEmpty, ownerName: ownerName, coverStyle: coverStyle,
                             entered: entered, onShare: { showShare = true }, onOpenPages: openPages, onCover: openPages)
            Group {
                if derived.isEmpty { PassportFirstStampCard(scale: s) { env.router.select(.discover) } }
                else { PassportTicketView(metrics: derived.metrics, scale: s, onSelect: ticketTapped) }
            }
            .frame(maxWidth: 560 - 28 * s).padding(.horizontal, 14 * s).frame(maxWidth: .infinity)
            .padding(.top, -62 * s)
            .offset(y: entered || reduceMotion ? 0 : 70).opacity(entered ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.65, dampingFraction: 0.85).delay(0.12), value: entered)
        }
    }

    // MARK: Populated

    private func populated(_ derived: PassportDerived, content: CGFloat, s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PassportSectionHeader(title: "Your stamps", identifier: "passport-stamps-title").padding(.horizontal, 20).padding(.top, 18 * s)
            Color.clear.frame(height: 44).padding(.top, 7)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("passportContent")).minY } action: { controlsTop = $0 }
            if model.query.hasActiveFilters {
                PassportFilterSummary(chips: derived.chips, shown: derived.visible.count, total: derived.all.count,
                                      onRemove: { kind in withAnimation { model.query.remove(kind) } }, onClearAll: { withAnimation { model.query.clearFilters() } })
                    .padding(.top, 10)
            }
            Group {
                if derived.visible.isEmpty { noResults.padding(.top, 20) }
                else {
                    switch model.layout {
                    case .grid: PassportGridView(entries: derived.visible, width: content, actions: actions, landed: landed).padding(.top, 24)
                    case .pages: PassportPagesView(entries: derived.visible, width: content, actions: actions, onAdd: { showAdd = true }, firstPageID: "pages").padding(.top, 24)
                    case .list: PassportListView(entries: derived.visible, actions: actions).padding(.top, 16)
                    }
                }
            }
            .id(ScrollTarget.grid)
            PassportFooterCard(total: derived.all.count, hidden: derived.hiddenCount, onExplore: { env.router.select(.discover) },
                               onClear: { withAnimation { model.query.clearFilters() } })
                .padding(.top, 28)
        }
    }

    private var noResults: some View {
        EmptyStateView(title: "No matching stamps", message: "Try removing a filter.", systemImage: "line.3.horizontal.decrease.circle",
                       actionTitle: "Clear filters") { withAnimation { model.query.clearFilters() } }
            .accessibilityIdentifier("passport-no-results")
    }

    private func emptyBody(content: CGFloat, s: CGFloat) -> some View {
        PassportEmptyState(width: content, onAdd: { showAdd = true }).padding(.top, 28 * s)
    }

    // MARK: Actions

    private var actions: PassportStampActions {
        PassportStampActions(open: { env.router.push(.stamp($0.destinationID)) },
                             toggleFavorite: { model.toggleFavorite($0) },
                             share: { entry in shareItem = passport.item(id: entry.destinationID) },
                             remove: { model.requestRemoval($0) })
    }

    private func openPages() {
        model.select(.pages)
        scrollTarget = .pages
    }

    private func openFilter(_ group: PassportFilterGroup?) {
        filterFocus = group
        showFilter = true
    }

    private func ticketTapped(_ cell: PassportTicketCell) {
        switch cell {
        case .collected:
            withAnimation { model.query.clearFilters() }
            scrollTarget = .grid
        case .verified:
            model.toggleVerifiedFilter()
            scrollTarget = .grid
        case .countries: openFilter(.country)
        case .sets: env.router.push(.collections)
        }
    }

    private func collectPending() {
        guard let id = pendingAdd else { return }
        pendingAdd = nil
        // The reveal is a full-screen cover; it can only present once the sheet has finished leaving.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            if let error = env.collect(id) { model.errorMessage = error.errorDescription }
        }
    }

    @ViewBuilder
    private var undoToast: some View {
        if let name = model.removedName(catalog: passport.catalog) {
            PassportUndoToast(name: name) { withAnimation { model.undoRemoval() } }
                .padding(.bottom, 96).transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// The glass title bar, and the controls that ride with the content until they reach the bar and pin to it. Reads the
/// scroll offset, so it is the only part of the screen that updates every frame of the first stretch of the scroll.
struct PassportChrome: View {
    let scroll: PassportScrollState
    @Bindable var model: PassportViewModel
    let barHeight: CGFloat
    let pinY: CGFloat
    let controlsTop: CGFloat
    let content: CGFloat
    let isEmpty: Bool
    let metrics: PassportMetrics
    let coverStyle: CoverStyle
    let onOpenFilter: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let offset = scroll.offset
        let barOpacity = isEmpty ? 0 : min(1, max(0, (offset - 100) / 40))
        let natural = controlsTop - offset
        let pinned = natural <= pinY
        ZStack(alignment: .top) {
            if !isEmpty {
                titleBar.opacity(barOpacity).allowsHitTesting(false)
                Rectangle().fill(.clear).frame(height: 60).cardGlass(Rectangle(), tint: 0.90, lined: false)
                    .overlay(alignment: .bottom) { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
                    .offset(y: barHeight).opacity(pinned ? 1 : 0).animation(.easeOut(duration: 0.15), value: pinned).allowsHitTesting(false)
                PassportControlsBar(model: model, onOpenFilter: onOpenFilter)
                    .frame(maxWidth: 560).padding(.horizontal, 20).frame(maxWidth: .infinity)
                    .offset(y: max(natural, pinY)).opacity(controlsTop > 0 ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    private var titleBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Passport").font(.system(size: 20, weight: .bold)).foregroundStyle(HomeColor.ink).accessibilityAddTraits(.isHeader)
                Text("^[\(metrics.collected) stamp](inflect: true), ^[\(metrics.countries) country](inflect: true)")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub)
            }
            Spacer()
            PassportCover(style: coverStyle, holderName: "", width: 30).rotationEffect(.degrees(4)).accessibilityHidden(true)
        }
        .frame(maxWidth: 560).padding(.horizontal, 24).padding(.bottom, 8).frame(maxWidth: .infinity)
        .frame(height: barHeight, alignment: .bottom)
        .cardGlass(Rectangle(), tint: 0.90, lined: false)
        .overlay(alignment: .bottom) { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
    }
}
