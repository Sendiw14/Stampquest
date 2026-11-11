import SwiftUI
import MapKit

/// The Map tab (Design M3 "Cover Frame"): a terracotta cover with the title and one line of counts, a rounded window that
/// holds the map, the layer chips and two round buttons, and a preview card that rises over the window's bottom.
struct MapTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View { MapContent(env: env) }
}

/// What has already played in this launch: the entrance runs on the first appearance only, not on every tab switch.
@MainActor
enum MapSession {
    static var hasEntered = false
}

struct MapContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var model: MapViewModel
    @State private var search: DiscoverSearchModel
    @State private var listSearch: DiscoverSearchModel
    @State private var entered = MapSession.hasEntered
    @State private var cardHeight: CGFloat = 0

    init(env: AppEnvironment) {
        _model = State(initialValue: MapViewModel(env: env))
        _search = State(initialValue: DiscoverSearchModel(catalog: env.catalog))
        _listSearch = State(initialValue: DiscoverSearchModel(catalog: env.catalog))
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }

    var body: some View {
        let derived = MapDerived(catalog: passport.catalog, snapshot: passport.snapshot)
        let visible = derived.visiblePlaces(model.layer)
        let selected = model.selectedID.flatMap { derived.place(id: $0) }
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    MapCountsLine(counts: derived.counts).padding(.horizontal, 24).padding(.top, 2).frame(maxWidth: 284, alignment: .leading)
                        .opacity(entered ? 1 : 0).animation(rise(0.55), value: entered)
                    window(derived: derived, visible: visible, selected: selected)
                        .padding(.top, 14).padding(.horizontal, 12).padding(.bottom, 12)
                }
                .padding(.top, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityHidden(model.isSearching)

                if model.showsList {
                    MapListView(derived: derived, layer: model.layer, topInset: 0, search: listSearch,
                                onLayer: { setLayer($0, derived: derived) }, onBack: { closeList() }, onOpen: { model.openDetail($0) })
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                        .zIndex(1)
                }
                if model.isSearching {
                    DiscoverSearchView(model: search, viewModel: model.actions, topInset: safeTop, onCancel: closeSearch,
                                       onOpenPlace: { id in closeSearch(); model.showPlace(id, derived: derived) })
                        .transition(.opacity).zIndex(2)
                }
            }
        }
        .background(cover.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(model.isSearching ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $model.showsGuide) {
            MapMarkerGuideSheet { model.showsGuide = false }
                .presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(36)
        }
        .sheet(isPresented: $model.showsExplainer) {
            MapLocationExplainerSheet(onContinue: { model.continueFromExplainer() }, onNotNow: { model.dismissExplainer() })
                .presentationDetents([.medium]).presentationDragIndicator(.visible).presentationCornerRadius(36)
        }
        .alert("Something went wrong", isPresented: Binding(get: { model.actions.errorMessage != nil }, set: { if !$0 { model.actions.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.actions.errorMessage ?? "") }
        .onAppear { appear(derived) }
        .onChange(of: env.router.selectedTab) { _, tab in if tab != .map { model.turnLocateOff() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.authorizationMayHaveChanged() } else { model.turnLocateOff() }
        }
        .onChange(of: model.selectedID) { _, id in
            guard let id, UIAccessibility.isVoiceOverRunning, let name = derived.place(id: id)?.destination.name else { return }
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Selected \(name)"))
        }
    }

    // MARK: Cover

    private var cover: some View {
        ZStack {
            LinearGradient(colors: [HomeColor.posterTop, HomeColor.posterMid, HomeColor.posterBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [HomeColor.glow.opacity(0.16), .clear], center: UnitPoint(x: 0.85, y: 0.05), startRadius: 0, endRadius: 360)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Map").font(.system(size: 38, weight: .heavy)).tracking(-0.04 * 38).foregroundStyle(MapColor.onCover)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("map-title")
                .offset(y: entered ? 0 : 12).opacity(entered ? 1 : 0).animation(rise(0.55), value: entered)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                MapRoundButton(symbol: "magnifyingglass", size: 40, onPoster: true, label: "Search", identifier: "map-search") { openSearch() }
                MapRoundButton(symbol: "list.bullet", size: 40, onPoster: true, label: "List of places", identifier: "map-list-button") { openList() }
            }
            .padding(.trailing, 22).offset(y: entered ? 0 : -8).opacity(entered ? 1 : 0).animation(rise(0.55).delay(0.05), value: entered)
        }
        .padding(.leading, 24)
    }

    // MARK: Window

    private func window(derived: MapDerived, visible: [MapPlace], selected: MapPlace?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        return ZStack(alignment: .topLeading) {
            HomeColor.page
            if model.mapUnavailable {
                unavailable(derived)
            } else {
                MapKitSurface(places: visible, derived: derived, selectedID: model.selectedID, userCoordinate: model.userCoordinate,
                              camera: model.camera, reduceMotion: reduceMotion,
                              onTapPlace: { model.tapPlace($0, derived: derived) },
                              onTapEmpty: { model.clearSelection(); model.dismissLocationOffBanner() },
                              onFail: { model.mapFailedToLoad() })
                    .id(model.mapGeneration)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text(verbatim: String(localized: "Map, \(derived.places.count.placesPhrase)")))
                    .accessibilityHint(Text("Use the List button for a list of places"))
                // Taken out (not just covered) while the List is open, so VoiceOver never reads two sets of chips.
                if !model.showsList { chrome(derived: derived, visible: visible, selected: selected).transition(.opacity) }
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(MapColor.windowBorder, lineWidth: 2).allowsHitTesting(false))
        .shadow(color: Color(red: 40 / 255, green: 12 / 255, blue: 0, opacity: 0.55), radius: 18, y: 18)
        .modifier(MapToastOverlay(center: env.toasts, bottomInset: 12 + (selected != nil ? cardHeight + 12 : 0)))
        .offset(y: entered ? 0 : 44).scaleEffect(entered ? 1 : 0.965).opacity(entered ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.3) : .easeOut(duration: 0.75), value: entered)
        .frame(maxHeight: .infinity)
    }

    private func chrome(derived: MapDerived, visible: [MapPlace], selected: MapPlace?) -> some View {
        ZStack(alignment: .topLeading) {
            MapLayerChips(layer: model.layer, counts: derived.counts, onSelect: { setLayer($0, derived: derived) })
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: entered ? 0 : 8).opacity(entered ? 1 : 0)

            VStack(spacing: 10) {
                MapRoundButton(symbol: model.isLocateOn ? "location.fill" : "location", filled: model.isLocateOn, label: "Locate me",
                               value: model.isLocateOn ? "On" : nil, identifier: "map-locate") { model.tapLocate() }
                MapRoundButton(symbol: "info", label: "Marker guide", identifier: "map-guide-button") { model.showsGuide = true }
            }
            .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 12).padding(.top, model.showsLocationOffBanner ? 164 : 62)
            .offset(y: entered ? 0 : 8).opacity(entered ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: model.showsLocationOffBanner)

            if model.showsLocationOffBanner {
                MapLocationOffBanner { model.openSettings() }
                    .padding(.horizontal, 12).padding(.top, 60).transition(.opacity)
            }

            VStack {
                Spacer()
                if let selected {
                    let state = derived.state(for: selected.id)
                    MapPreviewCard(place: selected, state: state,
                                   onOpen: { model.openDetail(selected.id) },
                                   onCollect: { model.collect(selected.id) },
                                   onToggleSave: { model.toggleSave(selected.id) },
                                   onOpenStamp: { model.openStamp(selected.id) })
                        .background(GeometryReader { Color.clear.preference(key: MapCardHeightKey.self, value: $0.size.height) })
                        .onPreferenceChange(MapCardHeightKey.self) { cardHeight = $0 }
                        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { if $0.translation.height > 40 { model.clearSelection() } })
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .offset(y: 64).combined(with: .opacity), removal: .offset(y: 36).combined(with: .opacity)))
                        .id(selected.id)
                } else if visible.isEmpty && !derived.places.isEmpty {
                    MapEmptyLayerCard(layer: model.layer) { setLayer(.all, derived: derived) }.transition(.opacity)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.4), value: model.selectedID)
            .animation(.easeInOut(duration: 0.2), value: visible.isEmpty)
        }
    }

    // MARK: Map unavailable

    private func unavailable(_ derived: MapDerived) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 30, weight: .regular)).foregroundStyle(HomeColor.label).accessibilityHidden(true)
                    Text("The map can’t load right now").font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.ink).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("You can still search and browse every place in the list below.").font(.system(size: 13.5)).foregroundStyle(HomeColor.sub).multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        Button { model.retryMap() } label: {
                            Text("Try again").font(.system(size: 14.5, weight: .bold)).foregroundStyle(HomeColor.ctaText).frame(minWidth: 120, minHeight: 38)
                                .background(HomeColor.cta, in: Capsule()).frame(minHeight: 44).contentShape(Capsule())
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("map-retry")
                        Button { openList() } label: {
                            Label("Open list", systemImage: "list.bullet").font(.system(size: 14.5, weight: .bold)).foregroundStyle(HomeColor.ink)
                                .frame(minWidth: 150, minHeight: 38).background(PassportColor.quiet, in: Capsule())
                                .overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1)).frame(minHeight: 44).contentShape(Capsule())
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("map-unavailable-open-list")
                    }
                }
                .padding(16).frame(maxWidth: .infinity).cardGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 4).padding(.top, 16).accessibilityElement(children: .contain)
                MapPlaceSections(destinations: derived.destinations, derived: derived, onOpen: { model.openDetail($0) }).padding(.top, 8).padding(.bottom, 24)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: Actions

    private func rise(_ duration: Double) -> Animation { reduceMotion ? .easeOut(duration: 0.25) : .easeOut(duration: duration) }

    private func appear(_ derived: MapDerived) {
        model.placeInitialCamera(derived: derived)
        guard !entered else { return }
        MapSession.hasEntered = true
        DispatchQueue.main.async { entered = true }
    }

    private func setLayer(_ layer: MapLayer, derived: MapDerived) {
        guard layer != model.layer else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.16) : .easeInOut(duration: 0.28)) { model.setLayer(layer, derived: derived) }
        let count: Int = switch layer { case .all: derived.places.count; case .collected: derived.counts.collected; case .verified: derived.counts.verified; case .saved: derived.counts.saved }
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: "\(layer.title), \(count.placesPhrase)")
        }
    }

    private func openSearch() {
        search.prepare()
        model.clearSelection()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35)) { model.isSearching = true }
    }

    private func closeSearch() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35)) { model.isSearching = false }
        search.clear()
    }

    private func openList() { withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.6)) { model.showsList = true } }
    private func closeList() { withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.6)) { model.showsList = false } }
}
