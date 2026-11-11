import SwiftUI

/// Search, in place of the timeline (the tab bar stays). Recent terms and tags when nothing is typed; ranked results with the
/// match highlighted; a card that hands a place query to Discover (only the query term, never memory text).
struct MemorySearchView: View {
    @Bindable var model: MemorySearchModel
    let viewModel: MemoriesViewModel
    let items: [MemoryItem]
    let topInset: CGFloat
    let onCancel: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var fieldSize = 17.0

    private var byID: [UUID: MemoryItem] { Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                switch model.phase {
                case .idle: idle.transition(.opacity)
                case .results(let ids): results(ids).transition(.opacity)
                case .noResults: noResults.transition(.opacity)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.3), value: phaseKey)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HomeColor.page.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .onAppear { model.setIndex(MemorySearchIndex(items: items, catalog: passport.catalog)); focused = true }
        .onChange(of: items) { _, new in model.setIndex(MemorySearchIndex(items: new, catalog: passport.catalog)) }
    }

    private var phaseKey: Int {
        switch model.phase {
        case .idle: 0
        case .results: 1
        case .noResults: 2
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium)).foregroundStyle(HomeColor.sub).accessibilityHidden(true)
                TextField("", text: Binding(get: { model.text }, set: { model.setText($0) }), prompt: Text("Search memories").foregroundStyle(HomeColor.sub))
                    .font(.system(size: fieldSize, weight: .medium)).foregroundStyle(HomeColor.ink).tint(HomeColor.label)
                    .focused($focused).submitLabel(.search).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .onSubmit(submit).accessibilityIdentifier("memory-search-field")
                if !model.text.isEmpty {
                    Button { model.clear(); focused = true } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(HomeColor.ink3).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).padding(.trailing, -14).accessibilityLabel(Text("Clear text")).accessibilityIdentifier("memory-search-clear")
                }
            }
            .padding(.horizontal, 14).frame(minHeight: 44)
            .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
            Button { focused = false; onCancel() } label: {
                Text("Cancel").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain).accessibilityIdentifier("memory-search-cancel")
        }
        .padding(.horizontal, 20).padding(.top, topInset + 4).padding(.bottom, 10).frame(maxWidth: .infinity)
        .cardGlass(Rectangle(), tint: 0.90, lined: false)
        .overlay(alignment: .bottom) { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
    }

    private func submit() {
        focused = false
        model.flush()
        viewModel.noteSearch(model.text)
    }

    // MARK: Empty query

    private var idle: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                let recents = env.preferences.recentMemorySearches
                let tags = MemoryDerived.tagCounts(items).prefix(12)
                if recents.isEmpty, tags.isEmpty {
                    Text("Search titles, text, places and tags.").font(.system(size: 15, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
                if !recents.isEmpty { recentBlock(recents) }
                if !tags.isEmpty { tagsBlock(Array(tags)) }
            }
            .frame(maxWidth: 560, alignment: .leading).padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 40).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func recentBlock(_ recents: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                label("Recent")
                Spacer()
                Button { withAnimation { viewModel.clearRecentSearches() } } label: {
                    Text("Clear").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain).accessibilityIdentifier("memory-recent-clear")
            }
            ForEach(Array(recents.enumerated()), id: \.element) { index, term in
                Button { run(term) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "clock").font(.system(size: 16, weight: .medium)).foregroundStyle(HomeColor.ink3).frame(width: 28)
                        Text(term).font(.system(size: fieldSize, weight: .medium)).foregroundStyle(HomeColor.ink).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 54).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(Text("Search for \(term)")).accessibilityIdentifier("memory-recent-\(index)")
                if index < recents.count - 1 { Rectangle().fill(PassportColor.cardLine).frame(height: 1).padding(.leading, 42) }
            }
        }
    }

    private func tagsBlock(_ tags: [(tag: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Tags")
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(tags, id: \.tag) { entry in
                    Button { run(entry.tag) } label: {
                        Text(entry.tag).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink).padding(.horizontal, 16).frame(minHeight: 38)
                            .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                            .frame(minHeight: 44).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("memory-search-tag-\(entry.tag)")
                }
            }
        }
    }

    private func run(_ term: String) {
        focused = false
        model.run(term: term)
        viewModel.noteSearch(term)
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.system(size: 13, weight: .bold)).tracking(0.02 * 13).foregroundStyle(HomeColor.sub).accessibilityAddTraits(.isHeader)
    }

    // MARK: Results

    private func results(_ ids: [UUID]) -> some View {
        let found = ids.compactMap { byID[$0] }
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("^[\(found.count) memory](inflect: true)").font(.system(size: 13, weight: .bold)).tracking(0.02 * 13).foregroundStyle(HomeColor.sub)
                    .padding(.top, 18).padding(.bottom, 6).accessibilityAddTraits(.isHeader).accessibilityIdentifier("memory-search-count")
                ForEach(Array(found.enumerated()), id: \.element.id) { index, item in
                    Button {
                        viewModel.noteSearch(model.text)
                        env.router.push(.memory(item.id))
                    } label: { MemoryCard(item: item, query: model.answeredQuery) }
                        .buttonStyle(.plain).accessibilityIdentifier("memory-result-\(item.displayTitle())")
                    if index < found.count - 1 { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
                }
                if hasPlaceMatch { placesCard.padding(.top, 20) }
            }
            .frame(maxWidth: 560, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 40).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Whether the query names at least one catalog place.
    private var hasPlaceMatch: Bool { !DiscoverSearchIndex.shared(for: passport.catalog).search(model.answeredQuery).places.isEmpty }

    private var placesCard: some View {
        Button {
            MemoryNavigation.shared.pendingDiscoverQuery = model.answeredQuery
            focused = false
            onCancel()
            env.router.select(.discover)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "mappin").font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.label).frame(width: 38, height: 38)
                    .background(PassportColor.accentTint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search places for “\(model.answeredQuery)”").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(2)
                    Text("Opens Discover").font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3)
            }
            .padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 82)
            .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier("memory-search-places")
    }

    private var noResults: some View {
        ScrollView {
            EmptyStateView(title: "No memories match “\(model.answeredQuery)”", message: "Try a place, a tag or a word from the text.", systemImage: "magnifyingglass")
                .padding(.top, 48).accessibilityIdentifier("memory-search-none")
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// "Filter memories": a draft. Nothing behind the sheet changes while it is open. The button applies it and shows the live
/// count; swipe down discards it (the VoiceOver escape gesture does too).
struct MemoryFilterSheet: View {
    let initial: MemoryFilter
    let items: [MemoryItem]
    let catalog: Catalog
    let snapshot: PassportSnapshot
    let onApply: (MemoryFilter) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: MemoryFilter
    @ScaledMetric(relativeTo: .title2) private var titleSize = 24.0

    init(initial: MemoryFilter, items: [MemoryItem], catalog: Catalog, snapshot: PassportSnapshot, onApply: @escaping (MemoryFilter) -> Void) {
        self.initial = initial
        self.items = items
        self.catalog = catalog
        self.snapshot = snapshot
        self.onApply = onApply
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                group("Sort by") {
                    chips(MemoryFilter.Sort.allCases.map { ($0.rawValue, $0.title, nil) }, selected: [draft.sort.rawValue], prefix: "sort") { id in
                        if let sort = MemoryFilter.Sort(rawValue: id) { draft.sort = sort }
                    }
                }
                let places = MemoryDerived.placeCounts(items, catalog: catalog)
                if !places.isEmpty {
                    group("Place") {
                        chips(places.map { ($0.id, $0.name, $0.count) }, selected: draft.placeIDs, prefix: "place") { id in
                            if !draft.placeIDs.insert(id).inserted { draft.placeIDs.remove(id) }
                        }
                    }
                }
                let tags = MemoryDerived.tagCounts(items)
                if !tags.isEmpty {
                    group("Tags") {
                        chips(tags.map { (MemoryTags.key($0.tag), $0.tag, $0.count) }, selected: draft.tagKeys, prefix: "tag") { key in
                            if !draft.tagKeys.insert(key).inserted { draft.tagKeys.remove(key) }
                        }
                    }
                }
                VStack(spacing: 0) {
                    switchRow(title: "Has photos", subtitle: "Hide notes without a picture", isOn: $draft.hasPhotos, id: "memory-filter-photos")
                    Rectangle().fill(PassportColor.cardLine).frame(height: 1)
                    switchRow(title: "Linked to a stamp", subtitle: "Memories tied to a collected place", isOn: $draft.linkedToStamp, id: "memory-filter-stamp")
                }
                .padding(.horizontal, 16).background(HomeColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
            }
            .padding(.horizontal, 24).padding(.top, 26).padding(.bottom, 120)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: draft)
        }
        .background(HomeColor.page.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { applyButton }
        // The VoiceOver escape gesture closes the sheet and discards the draft.
        .accessibilityAction(.escape) { onApply(initial) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Filter memories").font(.system(size: titleSize, weight: .heavy)).tracking(-0.035 * titleSize).foregroundStyle(HomeColor.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { withAnimation { draft = MemoryFilter() } } label: {
                Text("Reset").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
            .buttonStyle(.plain).disabled(draft.isDefault).opacity(draft.isDefault ? 0.55 : 1).accessibilityIdentifier("memory-filter-reset")
        }
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .bold)).tracking(0.02 * 13).foregroundStyle(HomeColor.sub).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func chips(_ items: [(id: String, title: String, count: Int?)], selected: Set<String>, prefix: String, toggle: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.id) { item in
                let on = selected.contains(item.id)
                Button { env.haptics.selection(); toggle(item.id) } label: {
                    HStack(spacing: 6) {
                        if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)) }
                        Text(item.title).font(.system(size: 13.5, weight: on ? .bold : .semibold)).lineLimit(1)
                        if let count = item.count { Text("\(count)").font(.system(size: 13.5, weight: .semibold)).opacity(0.8).monospacedDigit() }
                    }
                    .foregroundStyle(on ? HomeColor.ctaText : HomeColor.ink).padding(.horizontal, 16).frame(minHeight: 38)
                    .background(on ? HomeColor.cta : PassportColor.quiet, in: Capsule())
                    .overlay(Capsule().strokeBorder(on ? .clear : PassportColor.cardLine, lineWidth: 1))
                    .frame(minHeight: 44).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityLabel(item.count.map { Text("\(item.title), ^[\($0) memory](inflect: true)") } ?? Text(item.title))
                .accessibilityIdentifier("memory-filter-\(prefix)-\(item.id)")
            }
        }
    }

    private func switchRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, isOn: Binding<Bool>, id: String) -> some View {
        Button { env.haptics.selection(); isOn.wrappedValue.toggle() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink)
                    Text(subtitle).font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: isOn).labelsHidden().tint(HomeColor.cta).allowsHitTesting(false)
            }
            .frame(minHeight: 64).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(title, isOn: isOn).accessibilityHint(Text(subtitle)).accessibilityIdentifier(id) }
    }

    // MARK: Apply

    private var applyButton: some View {
        let count = draft.apply(to: items, snapshot: snapshot).count
        let empty = draft.isActive && count == 0
        return Button { onApply(draft) } label: {
            Group {
                if empty { Text("No memories match") } else { Text("Show ^[\(count) memory](inflect: true)") }
            }
            .font(.system(size: 17, weight: .bold)).foregroundStyle(HomeColor.ctaText).contentTransition(.opacity)
            .frame(maxWidth: .infinity, minHeight: 56).background(HomeColor.cta.opacity(empty ? 0.5 : 1), in: Capsule())
        }
        .buttonStyle(.plain).disabled(empty).animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: count)
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 10)
        .background { LinearGradient(colors: [HomeColor.page.opacity(0), HomeColor.page, HomeColor.page], startPoint: .top, endPoint: .bottom).ignoresSafeArea() }
        .accessibilityIdentifier("memory-filter-apply")
    }
}
