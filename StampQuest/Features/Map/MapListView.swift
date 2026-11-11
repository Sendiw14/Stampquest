import SwiftUI

/// The List screen (and the list under "map unavailable"): the same places and the same layer as the map, by region and
/// A to Z, with an offline search. Never needs the map.
struct MapListView: View {
    let derived: MapDerived
    let layer: MapLayer
    let topInset: CGFloat
    let search: DiscoverSearchModel
    let onLayer: (MapLayer) -> Void
    let onBack: () -> Void
    let onOpen: (String) -> Void

    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 36.0
    @ScaledMetric(relativeTo: .body) private var fieldSize = 16.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: topInset + 3)
            backPill.padding(.leading, 20)
            Text("Places").font(.system(size: titleSize, weight: .heavy)).tracking(-0.04 * titleSize).foregroundStyle(HomeColor.ink)
                .padding(.leading, 24).padding(.top, 6).accessibilityAddTraits(.isHeader).accessibilityIdentifier("map-list-title")
            searchField.padding(.horizontal, 16).padding(.top, 8)
            MapLayerChips(layer: layer, counts: derived.counts, glass: false, onSelect: onLayer).padding(.horizontal, 24).padding(.top, 2)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HomeColor.page.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [HomeColor.page.opacity(0), HomeColor.page], startPoint: .top, endPoint: .bottom)
                .frame(height: 40).allowsHitTesting(false).ignoresSafeArea(edges: .bottom)
        }
        .onAppear { search.prepare() }
    }

    // MARK: Header

    private var backPill: some View {
        Button(action: onBack) {
            HStack(spacing: 6) {
                Image(systemName: "map").font(.system(size: 15, weight: .semibold))
                Text("Map").font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(HomeColor.ink).padding(.horizontal, 14).frame(minWidth: 92, minHeight: 36)
            .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .frame(minHeight: 44).contentShape(Capsule())
        }
        .buttonStyle(.plain).padding(.vertical, -4).accessibilityLabel(Text("Back to the map")).accessibilityIdentifier("map-list-back")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium)).foregroundStyle(HomeColor.sub).accessibilityHidden(true)
                TextField("", text: Binding(get: { search.text }, set: { search.setText($0) }),
                          prompt: Text("Search places or landmarks").foregroundStyle(HomeColor.sub))
                    .font(.system(size: fieldSize, weight: .medium)).foregroundStyle(HomeColor.ink).tint(HomeColor.label)
                    .focused($focused).submitLabel(.search).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityIdentifier("map-list-search")
                if !search.text.isEmpty {
                    Button { search.clear(); focused = true } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(HomeColor.ink3).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).padding(.trailing, -14).accessibilityLabel(Text("Clear text")).accessibilityIdentifier("map-list-search-clear")
                }
            }
            .padding(.horizontal, 14).frame(minHeight: 46)
            .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
            if focused || !search.text.isEmpty {
                Button { search.clear(); focused = false } label: {
                    Text("Cancel").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain).accessibilityIdentifier("map-list-search-cancel")
            }
        }
    }

    // MARK: Rows

    /// The destinations to show: the layer's places, narrowed by the search when there is one. Places without coordinates are in.
    private var shown: [Destination]? {
        let inLayer = derived.visibleDestinations(layer)
        let query = search.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return inLayer }
        switch search.phase {
        case .results:
            let found = search.results(in: .all)
            let ids = Set(found.places.map(\.destinationID) + found.landmarks.map(\.destinationID))
            return inLayer.filter { ids.contains($0.id) }
        case .noResults: return []
        case .idle, .unavailable: return nil   // typed, the answer has not arrived: keep the last rows below
        }
    }

    @ViewBuilder
    private var content: some View {
        let rows = shown ?? derived.visibleDestinations(layer)
        if rows.isEmpty { empty } else {
            ScrollView {
                MapPlaceSections(destinations: rows, derived: derived, onOpen: onOpen).padding(.top, 6).padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private var empty: some View {
        let typed = !search.text.trimmingCharacters(in: .whitespaces).isEmpty
        ScrollView {
            if typed {
                EmptyStateView(title: "No places match", message: "Check the spelling, or try a country or a landmark.", systemImage: "magnifyingglass")
                    .padding(.top, 40)
            } else {
                EmptyStateView(title: layerTitle, message: layerMessage, systemImage: "mappin", actionTitle: "Show all places") { onLayer(.all) }
                    .padding(.top, 40).accessibilityIdentifier("map-list-empty")
            }
        }
    }

    private var layerTitle: LocalizedStringKey {
        switch layer {
        case .verified: "No verified visits yet"
        case .collected: "Nothing collected yet"
        case .saved: "Nothing saved yet"
        case .all: "No places yet"
        }
    }

    private var layerMessage: LocalizedStringKey {
        switch layer {
        case .verified: "Verify a visit from a place’s page and it appears here."
        case .collected: "Collect a place and it appears here."
        case .saved: "Tap the bookmark on a place to save it for later."
        case .all: "There are no places to list."
        }
    }
}

/// Places by region in catalog region order, A to Z inside a region.
struct MapPlaceSections: View {
    let destinations: [Destination]
    let derived: MapDerived
    let onOpen: (String) -> Void
    @ScaledMetric(relativeTo: .footnote) private var headerSize = 13.0

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Region.allCases) { region in
                let inRegion = destinations.filter { $0.region == region }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                if !inRegion.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text(region.title).font(.system(size: headerSize, weight: .bold)).tracking(0.02 * headerSize).foregroundStyle(HomeColor.sub)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text("^[\(inRegion.count) place](inflect: true)").font(.system(size: headerSize, weight: .semibold)).foregroundStyle(HomeColor.sub)
                    }
                    .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 6)
                    ForEach(Array(inRegion.enumerated()), id: \.element.id) { index, destination in
                        if index > 0 { Rectangle().fill(PassportColor.cardLine).frame(height: 1).padding(.leading, 82).padding(.trailing, 20) }
                        Button { onOpen(destination.id) } label: { MapListRow(destination: destination, state: derived.state(for: destination.id), design: derived.place(id: destination.id)?.design) }
                            .buttonStyle(.plain).accessibilityIdentifier("map-row-\(destination.id)")
                    }
                }
            }
        }
    }
}

/// A place in the List: stamp, name, "Country · Category", and where it stands. Gold only for Verified.
struct MapListRow: View {
    let destination: Destination
    let state: StampState
    let design: StampDesign?
    @ScaledMetric(relativeTo: .headline) private var titleSize = 16.5
    @ScaledMetric(relativeTo: .footnote) private var subSize = 12.5

    var body: some View {
        HStack(spacing: 20) {
            Group {
                if let design { PerforatedStampView(design: design, showsTitle: false, isDecorative: true, lifted: false, aspectRatio: 3.0 / 4.0).frame(width: 38) }
                else { MapStampPlaceholder().frame(width: 34, height: 44).frame(width: 38) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name).font(.system(size: titleSize, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(2)
                Text(destination.countryCategoryLine).font(.system(size: subSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2)
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.leading, 24).padding(.trailing, 20).padding(.vertical, 7).frame(minHeight: 64).contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(destination.name), \(destination.countryName), \(destination.category.singularTitle)"))
        .accessibilityValue(Text(spoken))
        .accessibilityAddTraits(.isButton)
    }

    private var spoken: String {
        switch state {
        case .notCollected: ""
        case .wishlisted: String(localized: "On your wishlist")
        case .collected: String(localized: "In your passport")
        case .verified: String(localized: "Verified visit")
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch state {
        case .verified:
            HStack(spacing: 5) { VerifiedSeal(size: 17); Text("Verified").font(.system(size: 12, weight: .semibold)).foregroundStyle(HomeColor.ink) }
        case .collected:
            HStack(spacing: 4) { Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)); Text("In passport").font(.system(size: 12, weight: .semibold)) }
                .foregroundStyle(HomeColor.label)
        case .wishlisted:
            HStack(spacing: 4) { Image(systemName: "bookmark.fill").font(.system(size: 13, weight: .bold)); Text("Saved").font(.system(size: 12, weight: .semibold)) }
                .foregroundStyle(HomeColor.label)
        case .notCollected:
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3).accessibilityHidden(true)
        }
    }
}
