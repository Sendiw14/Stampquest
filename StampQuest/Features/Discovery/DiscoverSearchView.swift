import SwiftUI

/// Search, presented over Discover with the keyboard up. Recent and Try when nothing is typed; grouped results with scope
/// chips otherwise; a designed no-results state; and an error state that is never an empty list.
struct DiscoverSearchView: View {
    @Bindable var model: DiscoverSearchModel
    let viewModel: DiscoverViewModel
    let topInset: CGFloat
    let onCancel: () -> Void
    /// Where a tapped place goes. Nil opens its detail screen (Discover); the Map shows the place on the map instead.
    var onOpenPlace: ((String) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var fieldSize = 17.0
    @ScaledMetric(relativeTo: .headline) private var rowTitle = 17.0
    @ScaledMetric(relativeTo: .footnote) private var rowSub = 13.0

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                switch model.phase {
                case .idle: idle.transition(.opacity)
                case .results: results.transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                case .noResults: noResults.transition(.opacity)
                case .unavailable: unavailable.transition(.opacity)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.25), value: phaseKey)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HomeColor.page.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .onAppear { focused = true }
    }

    private var phaseKey: Int {
        switch model.phase {
        case .idle: 0
        case .results: 1
        case .noResults: 2
        case .unavailable: 3
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium)).foregroundStyle(HomeColor.sub).accessibilityHidden(true)
                TextField("", text: Binding(get: { model.text }, set: { model.setText($0) }),
                          prompt: Text("Search places or landmarks").foregroundStyle(HomeColor.sub))
                    .font(.system(size: fieldSize, weight: .medium)).foregroundStyle(HomeColor.ink).tint(HomeColor.label)
                    .focused($focused).submitLabel(.search).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .onSubmit(submit).accessibilityIdentifier("search-field")
                if !model.text.isEmpty {
                    Button { model.clear(); focused = true } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(HomeColor.ink3).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).padding(.trailing, -14).accessibilityLabel(Text("Clear text")).accessibilityIdentifier("search-clear")
                }
            }
            .padding(.leading, 14).padding(.trailing, 14).frame(minHeight: 44)
            .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
            Button { focused = false; onCancel() } label: {
                Text("Cancel").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain).accessibilityIdentifier("search-cancel")
        }
        .padding(.horizontal, 20).padding(.top, topInset + 4).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .cardGlass(Rectangle(), tint: 0.90, lined: false)
        .overlay(alignment: .bottom) { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
    }

    private func submit() {
        focused = false
        model.flush()
        viewModel.noteSearch(model.text)
    }

    // MARK: Idle: Recent and Try

    private var idle: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                let recents = Array(env.preferences.recentSearches.prefix(5))
                if !recents.isEmpty { recentBlock(recents) }
                if !model.ideas.isEmpty { tryBlock }
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
                .buttonStyle(.plain).accessibilityIdentifier("search-recent-clear")
            }
            ForEach(Array(recents.enumerated()), id: \.element) { index, term in
                HStack(spacing: 0) {
                    Button { run(term) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "clock").font(.system(size: 16, weight: .medium)).foregroundStyle(HomeColor.ink3).frame(width: 28)
                            Text(term).font(.system(size: fieldSize, weight: .medium)).foregroundStyle(HomeColor.ink).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 54).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel(Text("Search for \(term)")).accessibilityIdentifier("search-recent-\(index)")
                    Button { model.insert(term); focused = true } label: {
                        Image(systemName: "arrow.up.right").font(.system(size: 15, weight: .medium)).foregroundStyle(HomeColor.ink3).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel(Text("Use \(term) in the search field")).accessibilityIdentifier("search-recent-insert-\(index)")
                }
                if index < recents.count - 1 { Rectangle().fill(PassportColor.cardLine).frame(height: 1).padding(.leading, 42) }
            }
        }
    }

    private var tryBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Try")
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(model.ideas, id: \.self) { idea in ideaChip(idea) }
            }
        }
    }

    private func ideaChip(_ idea: String) -> some View {
        Button { run(idea) } label: {
            Text(idea).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink).padding(.horizontal, 16).frame(minHeight: 38)
                .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                .frame(minHeight: 44).contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier("search-idea-\(idea)")
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

    private var results: some View {
        let visible = model.results(in: model.scope)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                scopeChips.padding(.top, 14)
                if !visible.places.isEmpty { group("Places") { placeRows(visible.places) } }
                if !visible.landmarks.isEmpty { group("Landmarks") { landmarkRows(visible.landmarks) } }
                if !visible.collections.isEmpty { group("Collections") { collectionRows(visible.collections) } }
            }
            .frame(maxWidth: 560, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 40).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscoverSearchModel.Scope.allCases) { scope in
                    let selected = model.scope == scope
                    Button {
                        if !selected { env.haptics.selection() }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { model.scope = scope }
                    } label: {
                        Text(scope.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(selected ? HomeColor.ctaText : HomeColor.ink)
                            .padding(.horizontal, 16).frame(minHeight: 34)
                            .background(selected ? HomeColor.cta : PassportColor.quiet, in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? .clear : PassportColor.cardLine, lineWidth: 1))
                            .frame(minHeight: 44).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("search-scope-\(scope.rawValue)")
                }
            }
        }
        .scrollClipDisabled()
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title).padding(.top, 14)
            content()
        }
    }

    private func divider(_ last: Bool) -> some View {
        Group { if !last { Rectangle().fill(PassportColor.cardLine).frame(height: 1) } }
    }

    private func placeRows(_ places: [DiscoverSearchResults.Place]) -> some View {
        let items = places.compactMap { passport.item(id: $0.destinationID) }
        return ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            Button { open(item.id) } label: { DiscoverPlaceRow(item: item, query: model.answeredQuery) }
                .buttonStyle(.plain).accessibilityIdentifier("search-place-\(item.id)")
            divider(index == items.count - 1)
        }
    }

    private func landmarkRows(_ landmarks: [DiscoverSearchResults.Landmark]) -> some View {
        let rows = landmarks.compactMap { hit in passport.item(id: hit.destinationID).map { (hit, $0) } }
        return ForEach(Array(rows.enumerated()), id: \.element.0.destinationID) { index, row in
            let (hit, item) = row
            Button { open(item.id) } label: {
                HStack(spacing: 14) {
                    DiscoverStamp(design: item.design, name: item.destination.name, lifted: false).frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DiscoverHighlight.attributed(hit.landmark, query: model.answeredQuery)).font(.system(size: rowTitle, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(2)
                        Text(DiscoverHighlight.attributed("Landmark in \(item.destination.name), \(item.destination.countryName)", query: model.answeredQuery))
                            .font(.system(size: rowSub, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.ink3).accessibilityHidden(true)
                }
                .padding(.vertical, 6).frame(minHeight: 56).contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(hit.landmark), landmark in \(item.destination.name), \(item.destination.countryName)"))
                .accessibilityAddTraits(.isButton)
            }
            .buttonStyle(.plain).accessibilityIdentifier("search-landmark-\(item.id)")
            divider(index == rows.count - 1)
        }
    }

    private func collectionRows(_ hits: [DiscoverSearchResults.Collection]) -> some View {
        let rows = hits.compactMap { hit in passport.catalog.collection(id: hit.collectionID).map { (hit, $0) } }
        return ForEach(Array(rows.enumerated()), id: \.element.0.collectionID) { index, row in
            let (hit, collection) = row
            let thumbs = collection.destinationIDs.prefix(2).compactMap { passport.item(id: $0) }
            Button { openCollection(collection.id) } label: {
                HStack(spacing: 14) {
                    ZStack(alignment: .leading) {
                        ForEach(Array(thumbs.enumerated()), id: \.element.id) { i, item in
                            DiscoverStamp(design: item.design, name: item.destination.name, lifted: false).frame(width: 40)
                                .rotationEffect(.degrees(i == 0 ? -4 : 3)).offset(x: CGFloat(i) * 18)
                        }
                    }
                    .frame(width: 60, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DiscoverHighlight.attributed(collection.title, query: model.answeredQuery)).font(.system(size: rowTitle, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(2)
                        collectionSubline(collection, member: hit.memberName).font(.system(size: rowSub, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.ink3).accessibilityHidden(true)
                }
                .padding(.vertical, 6).frame(minHeight: 56).contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(collection.title), collection. ^[\(collection.destinationIDs.count) place](inflect: true)" + (hit.memberName.map { ", includes \($0)" } ?? "")))
                .accessibilityAddTraits(.isButton)
            }
            .buttonStyle(.plain).accessibilityIdentifier("search-collection-\(collection.id)")
            divider(index == rows.count - 1)
        }
    }

    private func collectionSubline(_ collection: StampCollection, member: String?) -> Text {
        let count = Text("^[\(collection.destinationIDs.count) place](inflect: true)")
        guard let member else { return count }
        return count + Text(" · includes ") + Text(DiscoverHighlight.attributed(member, query: model.answeredQuery))
    }

    private func open(_ destinationID: String) {
        viewModel.noteSearch(model.text)
        if let onOpenPlace { onOpenPlace(destinationID) } else { env.router.push(.destination(destinationID)) }
    }

    private func openCollection(_ id: String) {
        viewModel.noteSearch(model.text)
        env.router.push(.collection(id))
    }

    // MARK: No results, error

    private var noResults: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: "magnifyingglass").font(.system(size: 30, weight: .medium)).foregroundStyle(HomeColor.label)
                    .frame(width: 72, height: 72).background(PassportColor.accentTint, in: Circle()).accessibilityHidden(true)
                Text("No places match “\(model.answeredQuery)”").font(.system(size: 24, weight: .heavy)).tracking(-0.03 * 24).foregroundStyle(HomeColor.ink)
                    .multilineTextAlignment(.center).padding(.top, 22).accessibilityAddTraits(.isHeader)
                Text("Check the spelling, or try a country, a landmark or an interest.").font(.system(size: 15, weight: .regular)).foregroundStyle(HomeColor.sub)
                    .multilineTextAlignment(.center).frame(maxWidth: 282).padding(.top, 10)
                if !model.ideas.isEmpty {
                    FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(model.ideas, id: \.self) { ideaChip($0) } }
                        .frame(maxWidth: 360).padding(.top, 28)
                }
                Button { env.router.push(.interests) } label: {
                    Text("Browse all interests").font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.top, 20).accessibilityIdentifier("search-browse-interests")
            }
            .padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 40).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var unavailable: some View {
        VStack {
            InlineErrorView(title: "Search isn’t available right now",
                            message: String(localized: "The place catalog couldn’t be opened. Try again, or restart the app."),
                            retry: { model.prepare() })
                .padding(20).frame(maxWidth: 560)
            Spacer()
        }
    }
}
