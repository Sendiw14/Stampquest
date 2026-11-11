import SwiftUI
import SwiftData

/// The Memories tab (Design N1 "Dated Pages"): a terracotta header with a search ticket, then months and entries on a dotted
/// spine, each entry shaped by the photos it holds.
struct MemoriesView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View { MemoriesContent(env: env) }
}

/// What has already played in this launch: the entrance runs on the first appearance only.
@MainActor
enum MemoriesSession {
    static var hasEntered = false
}

/// The scroll offset lives in its own object so only the glass bar re-renders while scrolling.
@MainActor
@Observable
final class MemoriesScrollState { var offset: CGFloat = 0 }

struct MemoriesContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: [SortDescriptor(\MemoryEntry.eventDate, order: .reverse), SortDescriptor(\MemoryEntry.createdAt, order: .reverse)])
    private var memories: [MemoryEntry]
    @State private var model: MemoriesViewModel
    @State private var search = MemorySearchModel()
    @State private var scroll = MemoriesScrollState()
    @State private var filter = MemoryFilter()
    @State private var entered: Bool
    @State private var isSearching = false
    @State private var showFilters = false
    @State private var showCreate = false
    @State private var editing: MemoryEntry?
    @State private var pendingDelete: MemoryItem?
    private let handoff = MemoryNavigation.shared

    init(env: AppEnvironment) {
        _model = State(initialValue: MemoriesViewModel(env: env))
        _entered = State(initialValue: MemoriesSession.hasEntered)
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }

    var body: some View {
        let all = memories.map(MemoryItem.init)
        let visible = filter.apply(to: all, snapshot: passport.snapshot)
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let content = min(proxy.size.width, 560)
            let u = min(1.10, max(0.93, content / 402))
            let extra = max(0, safeTop - 54)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        ScrollOffsetAnchor(space: "memoriesScroll").id("top")
                        hero(all, u: u, extra: extra)
                        Group {
                            if all.isEmpty { MemoriesFirstRun(u: u) { showCreate = true } }
                            else { timeline(visible, all: all, u: u, width: content) }
                        }
                        .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 130)
                    .frame(width: proxy.size.width)
                }
                .modifier(ScrollOffsetReader(offset: Binding(get: { scroll.offset }, set: { scroll.offset = $0 }), space: "memoriesScroll", limit: 200))
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .top) {
                    if !all.isEmpty {
                        MemoriesChrome(scroll: scroll, barHeight: safeTop + 64, safeTop: safeTop, memoryCount: all.count, placeCount: MemoryDerived.placeCount(all),
                                       activeFilters: filter.chips.count, onSearch: openSearch, onNew: { showCreate = true })
                    }
                }
                .onChange(of: env.router.tabReselect) { _, _ in
                    guard env.router.selectedTab == .memories, env.router.path(for: .memories).isEmpty else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { reader.scrollTo("top", anchor: .top) }
                }
                // A new set of filters starts at the top, where the chips and "Clear all" are, not at an old scroll position.
                .onChange(of: filter) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { reader.scrollTo("top", anchor: .top) }
                }
            }
            .overlay {
                if isSearching {
                    MemorySearchView(model: search, viewModel: model, items: all, topInset: safeTop, onCancel: closeSearch)
                        .transition(.opacity)
                }
            }
        }
        .background(HomeColor.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .discoverToast(env.toasts, bottomInset: 96)
        .onAppear { runEntrance(); applyHandoff() }
        .onChange(of: handoff.pendingTag) { _, _ in applyHandoff() }
        .onChange(of: handoff.pendingPlaceID) { _, _ in applyHandoff() }
        .sheet(isPresented: $showCreate) { MemoryEditorSheet() }
        .sheet(item: $editing) { MemoryEditorSheet(memory: $0) }
        .sheet(isPresented: $showFilters) {
            MemoryFilterSheet(initial: filter, items: all, catalog: passport.catalog, snapshot: passport.snapshot) { filter = $0; showFilters = false }
                .presentationDetents([.medium, .large], selection: .constant(.large))
                .presentationDragIndicator(.visible).presentationCornerRadius(36)
        }
        .alert("Delete this memory?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { item in
            Button("Delete memory", role: .destructive) { model.delete(item.id) }
            Button("Cancel", role: .cancel) {}
        } message: { MemoryDeleteCopy.message(for: $0, catalog: passport.catalog) }
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }

    // MARK: Entrance, search, hand-offs

    private func runEntrance() {
        guard !MemoriesSession.hasEntered else { return }
        MemoriesSession.hasEntered = true
        entered = true
    }

    private func openSearch() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35)) { isSearching = true }
    }

    private func closeSearch() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35)) { isSearching = false }
        search.clear()
    }

    /// "Open the timeline filtered by this tag" from Detail.
    private func applyHandoff() {
        if let tag = handoff.pendingTag {
            handoff.pendingTag = nil
            filter = MemoryFilter(tagKeys: [MemoryTags.key(tag)])
        } else if let place = handoff.pendingPlaceID {
            handoff.pendingPlaceID = nil
            filter = MemoryFilter(placeIDs: [place])
        }
    }

    // MARK: Hero

    private func hero(_ all: [MemoryItem], u: CGFloat, extra: CGFloat) -> some View {
        VStack(spacing: 0) {
            MemoriesHeroView(scale: u, topExtra: extra, memoryCount: all.count, placeCount: MemoryDerived.placeCount(all),
                             prints: MemoryDerived.prints(all), entered: entered, onNew: { showCreate = true }, onSearch: openSearch)
            if !all.isEmpty {
                MemoriesTicketView(scale: u, activeFilters: filter.chips.count, onSearch: openSearch, onFilters: { showFilters = true })
                    .frame(maxWidth: 560 - 28 * u).padding(.horizontal, 14 * u).frame(maxWidth: .infinity)
                    .padding(.top, -30 * u)
                    .offset(y: entered || reduceMotion ? 0 : 16).opacity(entered ? 1 : 0)
                    .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.85).delay(0.12), value: entered)
            }
        }
    }

    // MARK: Timeline

    @ViewBuilder
    private func timeline(_ visible: [MemoryItem], all: [MemoryItem], u: CGFloat, width: CGFloat) -> some View {
        let collapsed = typeSize.isAccessibilitySize
        let sections = MemoryDerived.sections(visible)
        VStack(alignment: .leading, spacing: 0) {
            if filter.isActive {
                MemoryFilterSummary(filter: filter, catalog: passport.catalog, shown: visible.count, total: all.count,
                                    onRemove: { chip in withAnimation { filter.remove(chip) } },
                                    onOpen: { showFilters = true }, onClearAll: { withAnimation { filter.clearFilters() } })
                    .padding(.top, 14)
            }
            if visible.isEmpty {
                EmptyStateView(title: "No matching memories", message: "Try removing a filter.", systemImage: "line.3.horizontal.decrease.circle",
                               actionTitle: "Clear filters") { withAnimation { filter.clearFilters() } }
                    .padding(.top, 24).accessibilityIdentifier("memories-no-results")
            }
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 0) {
                    MemoryMonthHeader(date: section.monthStart, count: section.count).padding(.horizontal, 20)
                    VStack(alignment: .leading, spacing: 22 * u) {
                        ForEach(section.items) { item in entry(item, u: u, collapsed: collapsed) }
                    }
                    .padding(.top, 22 * u)
                    .background(alignment: .topLeading) {
                        if !collapsed { DottedRule(vertical: true).padding(.leading, 90 * u).padding(.top, 34 * u).padding(.bottom, 40) }
                    }
                }
                .padding(.top, 28 * u)
            }
            if filter.isActive, !visible.isEmpty { MemoryEndCard(count: visible.count).padding(.horizontal, 20).padding(.top, 32 * u) }
            Button { env.router.push(.trips) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "suitcase").font(.system(size: 14, weight: .semibold))
                    Text("Trips").memoryFont(14.5, .semibold, relativeTo: .subheadline)
                }
                .foregroundStyle(HomeColor.label).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.horizontal, 24).padding(.top, 28).accessibilityIdentifier("trips-button")
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: visible.map(\.id))
    }

    private func entry(_ item: MemoryItem, u: CGFloat, collapsed: Bool) -> some View {
        Button { env.router.push(.memory(item.id)) } label: {
            MemoryTimelineItem(item: item, u: u, collapsed: collapsed, onEdit: { editing = model.entry(item.id) }, onDelete: { pendingDelete = item })
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("memory-\(item.displayTitle())")
    }
}

/// "Delete this memory?" says what goes and what stays (the place's stamp, the photo library, the trips).
enum MemoryDeleteCopy {
    @MainActor
    static func message(for item: MemoryItem, catalog: Catalog) -> Text {
        let title = item.displayTitle()
        if let id = item.destinationID, let place = catalog.destination(id: id) {
            return Text("“\(title)” will be removed from StampQuest. Your photo library, your \(place.name) stamp and your trips stay as they are.")
        }
        return Text("“\(title)” will be removed from StampQuest. Your photo library and your trips stay as they are.")
    }
}

// MARK: - Header

struct MemoriesHeroView: View {
    let scale: CGFloat
    let topExtra: CGFloat
    let memoryCount: Int
    let placeCount: Int
    let prints: [String]
    let entered: Bool
    let onNew: () -> Void
    let onSearch: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38.0
    @ScaledMetric(relativeTo: .subheadline) private var subSize = 15.0
    @ScaledMetric(relativeTo: .subheadline) private var pillSize = 14.0
    private var u: CGFloat { scale }
    private var isEmpty: Bool { memoryCount == 0 }
    private var height: CGFloat { (isEmpty ? 236 : 300) * u }

    var body: some View {
        ZStack(alignment: .top) {
            PosterBackground()
            ZStack(alignment: .topLeading) {
                if !isEmpty { printsView }
                column
                if !isEmpty { searchCircle }
            }
            .frame(width: 402 * u, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity).frame(minHeight: height + topExtra, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Memories").font(.system(size: titleSize * u, weight: .heavy)).tracking(-0.04 * titleSize * u)
                .foregroundStyle(HomeColor.onPoster).lineLimit(1).minimumScaleFactor(0.6).accessibilityAddTraits(.isHeader)
            subline.font(.system(size: subSize * u, weight: .semibold)).foregroundStyle(HomeColor.onPoster)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 2 * u).accessibilityIdentifier("memories-subline")
            newPill.padding(.top, 20 * u)
        }
        .frame(width: 220 * u, alignment: .leading)
        .padding(.leading, 24 * u).padding(.top, 98 * u + topExtra)
        .opacity(entered ? 1 : 0).offset(y: entered || reduceMotion ? 0 : 12)
        .animation(.easeOut(duration: 0.7), value: entered)
    }

    private var subline: Text {
        if isEmpty { return Text("Nothing here yet") }
        if placeCount == 0 { return Text("^[\(memoryCount) memory](inflect: true)") }
        return Text("^[\(memoryCount) memory](inflect: true) from ^[\(placeCount) place](inflect: true)")
    }

    private var newPill: some View {
        Button(action: onNew) {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 14 * u, weight: .bold))
                Text("New memory").font(.system(size: pillSize * u, weight: .semibold))
            }
            .foregroundStyle(HomeColor.cream).padding(.leading, 12 * u).padding(.trailing, 16 * u).frame(minHeight: 36 * u)
            .posterGlass(Capsule()).frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(Text("New memory")).accessibilityIdentifier("new-memory")
    }

    private var searchCircle: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass").font(.system(size: 17 * u, weight: .semibold)).foregroundStyle(HomeColor.cream)
                .frame(width: 40 * u, height: 40 * u).posterGlass(Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).offset(x: 336 * u, y: 60 * u + topExtra)
        .opacity(entered ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.2), value: entered)
        .accessibilityLabel(Text("Search memories")).accessibilityIdentifier("memories-search-circle")
    }

    /// The user's own photos as prints. Decorative, on device only, hidden from VoiceOver.
    private var printsView: some View {
        ZStack(alignment: .topLeading) {
            if prints.count > 1 { print(prints[1], width: 88, x: 232, y: 120, tilt: -8, delay: 0.05) }
            if let front = prints.first { print(front, width: 96, x: 288, y: 94, tilt: 7, delay: 0.0) }
        }
        .accessibilityHidden(true).allowsHitTesting(false)
    }

    private func print(_ file: String, width: CGFloat, x: CGFloat, y: CGFloat, tilt: Double, delay: Double) -> some View {
        MemoryPrint(filename: file, width: width * u, tilt: tilt)
            .offset(x: x * u, y: y * u + topExtra + (entered || reduceMotion ? 0 : -30))
            .opacity(entered ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.7, dampingFraction: 0.7).delay(delay), value: entered)
    }
}

/// The search ticket: the field opens Search, the round button opens Filters (with a count badge while filters are on).
struct MemoriesTicketView: View {
    let scale: CGFloat
    let activeFilters: Int
    let onSearch: () -> Void
    let onFilters: () -> Void
    @ScaledMetric(relativeTo: .body) private var textSize = 16.0
    private var u: CGFloat { scale }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSearch) {
                HStack(spacing: 8 * u) {
                    Image(systemName: "magnifyingglass").font(.system(size: 19 * u, weight: .medium)).foregroundStyle(HomeColor.sub).frame(width: 24 * u)
                    Text("Search memories").font(.system(size: textSize * u, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
                }
                .padding(.leading, 22 * u).frame(maxWidth: .infinity, minHeight: 58 * u, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(Text("Search memories")).accessibilityHint(Text("Opens search"))
            .accessibilityIdentifier("memories-search-field")

            Button(action: onFilters) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 16 * u, weight: .semibold)).foregroundStyle(HomeColor.ctaText)
                    .frame(width: 40 * u, height: 40 * u).background(HomeColor.cta, in: Circle())
                    .shadow(color: HomeColor.cta.opacity(0.40), radius: 8, y: 4)
                    .overlay(alignment: .topTrailing) { MemoryFilterBadge(count: activeFilters).offset(x: 4, y: -4) }
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.trailing, 9 * u)
            .accessibilityLabel(activeFilters == 0 ? Text("Filters") : Text("Filters, \(activeFilters) active"))
            .accessibilityIdentifier("memories-filter-button")
        }
        .frame(minHeight: 58 * u).cardGlass(RoundedRectangle(cornerRadius: 29 * u, style: .continuous), tint: 0.86)
        .shadow(color: HomeColor.shadow1.opacity(0.16), radius: 14, y: 8)
    }
}

/// The 18 pt count of active filters: ink fill, page-colored number.
struct MemoryFilterBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)").font(.system(size: 11, weight: .heavy)).monospacedDigit().foregroundStyle(HomeColor.page)
                .frame(minWidth: 18, minHeight: 18).background(HomeColor.ink, in: Circle()).accessibilityHidden(true)
        }
    }
}

/// The glass bar that takes over from the header: title, counts, and the same search and new-memory controls.
struct MemoriesChrome: View {
    let scroll: MemoriesScrollState
    let barHeight: CGFloat
    let safeTop: CGFloat
    let memoryCount: Int
    let placeCount: Int
    let activeFilters: Int
    let onSearch: () -> Void
    let onNew: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Starts to appear at about 110 pt of scroll and is fully there by about 170 pt.
        let opacity = min(1, max(0, (scroll.offset - 110) / 60))
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Memories").font(.system(size: 20, weight: .bold)).tracking(-0.02 * 20).foregroundStyle(HomeColor.ink).accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize {
                    Text("^[\(memoryCount) memory](inflect: true), ^[\(placeCount) place](inflect: true)").font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
            }
            Spacer(minLength: 8)
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.ink)
                    .frame(width: 42, height: 42).background(HomeColor.card, in: Circle()).overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                    .overlay(alignment: .topTrailing) { MemoryFilterBadge(count: activeFilters).offset(x: 4, y: -4) }
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(Text("Search memories")).accessibilityIdentifier("memories-bar-search")
            Button(action: onNew) {
                Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                    .frame(width: 42, height: 42).background(HomeColor.cta, in: Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(Text("New memory")).accessibilityIdentifier("memories-bar-new")
        }
        .padding(.horizontal, 24).padding(.trailing, -6).padding(.top, safeTop - 4).padding(.bottom, 6)
        .frame(maxWidth: .infinity).frame(height: barHeight, alignment: .bottom)
        .cardGlass(Rectangle(), tint: 0.96, lined: false)
        .overlay(alignment: .bottom) { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
        .opacity(opacity).allowsHitTesting(opacity > 0.6)
        .frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea(edges: .top)
        .accessibilityHidden(opacity < 0.6)
    }
}

// MARK: - Filtered timeline pieces

struct MemoryFilterSummary: View {
    let filter: MemoryFilter
    let catalog: Catalog
    let shown: Int
    let total: Int
    let onRemove: (MemoryFilter.Chip) -> Void
    let onOpen: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(filter.chips, id: \.self) { chip($0) } }
                Spacer(minLength: 0)
                Button(action: onClearAll) {
                    Text("Clear all").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain).accessibilityIdentifier("memories-clear-all")
            }
            Text("Showing \(shown) of \(total) memories").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.sub)
                .accessibilityIdentifier("memories-showing")
        }
        .padding(.horizontal, 20)
    }

    private func title(_ chip: MemoryFilter.Chip) -> String {
        switch chip {
        case .places:
            if filter.placeIDs.count == 1, let id = filter.placeIDs.first { return String(localized: "Place: \(catalog.destination(id: id)?.name ?? String(localized: "Place no longer in the catalog"))") }
            return String(localized: "\(filter.placeIDs.count) places")
        case .tags:
            if filter.tagKeys.count == 1, let key = filter.tagKeys.first { return String(localized: "Tag: \(key.capitalized)") }
            return String(localized: "\(filter.tagKeys.count) tags")
        case .photos: return String(localized: "With photos")
        case .stamp: return String(localized: "Linked to a stamp")
        }
    }

    private func chip(_ chip: MemoryFilter.Chip) -> some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                Text(title(chip)).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(HomeColor.label).lineLimit(1)
                    .padding(.leading, 14).padding(.trailing, 6).frame(minHeight: 32).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { onRemove(chip) } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(HomeColor.label).frame(width: 30, height: 32).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(Text("\(title(chip)), remove filter")).accessibilityIdentifier("memories-chip-remove-\(chip)")
        }
        .background(PassportColor.accentTint, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.accentBorder, lineWidth: 1))
        .padding(.vertical, -6).frame(minHeight: 44)
    }
}

/// The end of a filtered list: "That is all 2." and how to see everything.
struct MemoryEndCard: View {
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("That is all \(count).").font(.system(size: 17, weight: .bold)).foregroundStyle(HomeColor.ink)
            Text("Clear the filters to see everything.").font(.system(size: 13.5, weight: .medium)).foregroundStyle(HomeColor.sub)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - First run

/// Nothing here yet: a perforated page with two dashed frames and the one button that matters.
struct MemoriesFirstRun: View {
    let u: CGFloat
    let onNew: () -> Void
    @Environment(AppEnvironment.self) private var env
    @ScaledMetric(relativeTo: .title) private var titleSize = 25.0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                dashedFrame(icon: "plus").rotationEffect(.degrees(-3)).offset(x: -34, y: 4)
                dashedFrame(icon: "photo").rotationEffect(.degrees(2)).offset(x: 40, y: -4)
            }
            .frame(height: 120).padding(.top, 30).accessibilityHidden(true)
            VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in DottedRule().padding(.horizontal, 40) } }.padding(.top, 14).accessibilityHidden(true)
            Text("Your first memory").font(.system(size: titleSize, weight: .heavy)).tracking(-0.03 * titleSize).foregroundStyle(HomeColor.ink)
                .multilineTextAlignment(.center).padding(.top, 22).accessibilityAddTraits(.isHeader)
            Text("Write a few lines, add photos from your library and link a stamp.").font(.system(size: 14.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                .multilineTextAlignment(.center).padding(.horizontal, 36).padding(.top, 8)
            Button(action: onNew) {
                Text("New memory").font(.system(size: 16, weight: .bold)).foregroundStyle(HomeColor.ctaText).frame(minWidth: 170, minHeight: 48)
                    .background(HomeColor.cta, in: Capsule()).frame(minHeight: 48)
            }
            .buttonStyle(.plain).padding(.top, 22).accessibilityIdentifier("memories-first-new")
            HStack(spacing: 6) {
                Image(systemName: "lock").font(.system(size: 12, weight: .semibold))
                Text("Private by default").font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(HomeColor.sub).padding(.top, 18)
            Button { env.router.push(.trips) } label: {
                Text("Trips").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain).padding(.top, 6).padding(.bottom, 20).accessibilityIdentifier("trips-button")
        }
        .frame(maxWidth: .infinity)
        .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .shadow(color: HomeColor.shadow1.opacity(0.10), radius: 12, y: 6)
        .padding(.horizontal, 20).padding(.top, 26 * u)
    }

    private func dashedFrame(icon: String) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(HomeColor.ink3.opacity(0.6), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
            .frame(width: 124, height: 96)
            .overlay { Image(systemName: icon).font(.system(size: 24, weight: .regular)).foregroundStyle(HomeColor.label) }
    }
}
