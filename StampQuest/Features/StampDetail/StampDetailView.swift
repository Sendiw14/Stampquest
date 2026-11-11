import SwiftUI
import SwiftData

/// Stamp detail in the "S2 Stage" design: a terracotta poster holds the stamp on a giant cancellation ring, a glass ticket carries
/// the place and the state, and the actions change with the state. A quiet page follows. It handles all four situations of a
/// stamp (not collected, wishlisted, collected by hand, verified).
struct StampDetailView: View {
    let destinationID: String
    @Environment(AppEnvironment.self) private var env

    var body: some View { StampDetailContent(env: env, destinationID: destinationID) }
}

/// The scroll offset lives in its own object so only the sticky bar re-renders while scrolling.
@MainActor
@Observable
final class StampScrollState { var offset: CGFloat = 0 }

struct StampDetailContent: View {
    let destinationID: String

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var memories: [MemoryEntry]
    @Query(sort: [SortDescriptor(\Trip.createdAt, order: .reverse)]) private var trips: [Trip]
    @State private var model: StampDetailViewModel
    @State private var scroll = StampScrollState()
    @State private var showVerify = false
    @State private var showShare = false
    @State private var showMemoryEditor = false
    @State private var showNote = false
    @State private var confirmRemove = false
    @State private var sealPress = false
    @State private var sealLanded = true

    init(env: AppEnvironment, destinationID: String) {
        self.destinationID = destinationID
        _model = State(initialValue: StampDetailViewModel(env: env, destinationID: destinationID))
        _memories = Query(filter: #Predicate<MemoryEntry> { $0.destinationID == destinationID }, sort: [SortDescriptor(\MemoryEntry.eventDate, order: .reverse)])
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }

    var body: some View {
        Group {
            if let destination = passport.catalog.destination(id: destinationID) {
                stage(destination)
            } else {
                loadError
            }
        }
        .background(HomeColor.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .discoverToast(env.toasts, bottomInset: 24)
    }

    private var loadError: some View {
        VStack(spacing: 16) {
            InlineErrorView(title: "This stamp couldn’t be loaded.", message: String(localized: "Your passport is safe. Try again, or go back."), retry: {})
            Button("Back") { dismiss() }.accessibilityIdentifier("stamp-back")
        }
        .padding(20)
    }

    // MARK: The page

    @ViewBuilder
    private func stage(_ destination: Destination) -> some View {
        let design = passport.catalog.stamp(forDestination: destinationID)
        let state = StampDetailState(passport.snapshot.state(of: destinationID))
        let stamp = passport.snapshot.collectedStamp(forDestination: destinationID)
        let item = passport.item(id: destinationID)
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let width = min(proxy.size.width, 560)
            let u = min(1.10, max(0.93, width / 402))
            let extra = max(0, safeTop - 54)
            let layout = StageLayout(u: u, extra: extra, width: proxy.size.width)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        ScrollOffsetAnchor(space: "stampScroll").id("top")
                        poster(destination, design: design, state: state, stamp: stamp, layout: layout, u: u)
                        VStack(alignment: .leading, spacing: 0) {
                            StampStateTicket(name: destination.name, countryName: destination.countryName, categoryTitle: destination.category.singularTitle,
                                             state: state, collectedAt: stamp?.collectedAt, verifiedAt: stamp?.verifiedAt,
                                             canVerify: item != nil && env.preferences.locationVerificationEnabled, u: u) { showVerify = true }
                                .padding(.horizontal, 14 * u).padding(.top, -66 * u)
                            StampActionBar(state: state, isWorking: model.isWorking, canCollect: design != nil, canShare: item != nil,
                                           onCollect: { Task { await model.collect() } }, onWishlist: { model.toggleWishlist() },
                                           onAddMemory: { showMemoryEditor = true }, onShare: { showShare = true })
                                .padding(.horizontal, 24 * u).padding(.top, 24)
                            lowerPage(destination, design: design, state: state, stamp: stamp)
                                .padding(.top, 44)
                        }
                        .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    }
                    .frame(width: proxy.size.width)
                    .padding(.bottom, 48)
                }
                .modifier(ScrollOffsetReader(offset: Binding(get: { scroll.offset }, set: { scroll.offset = $0 }), space: "stampScroll", limit: 420))
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .top) {
                    StampDetailChrome(scroll: scroll, title: destination.name, barHeight: safeTop + 42, safeTop: safeTop,
                                      onBack: { dismiss() }, menu: { moreMenu(destination, state: state, stamp: stamp) })
                }
                .overlay(alignment: .bottom) { LinearGradient(colors: [HomeColor.page.opacity(0), HomeColor.page], startPoint: .top, endPoint: .bottom).frame(height: 68).allowsHitTesting(false).ignoresSafeArea(edges: .bottom) }
                .overlay { revealLayer(destination, design: design, layout: layout, safeTop: safeTop) }
                .onChange(of: state) { old, new in
                    if old == .collectedManual, new == .collectedVerified { playSealPress() }
                }
            }
        }
        .sheet(isPresented: $showVerify) { if let item { VerifyVisitSheet(item: item) } }
        .sheet(isPresented: $showShare) { if let item { ShareStampSheet(item: item) } }
        .sheet(isPresented: $showMemoryEditor) { MemoryEditorSheet(prefilledDestinationID: destinationID) }
        .sheet(isPresented: $showNote) { StampNoteSheet(destinationID: destinationID) }
        .alert("Remove \(destination.name) from your passport?", isPresented: $confirmRemove) {
            Button("Remove stamp", role: .destructive) { model.remove(name: destination.name) }
            Button("Cancel", role: .cancel) {}
        } message: { removeMessage(destination.name, verified: state.isVerified) }
        .alert(failureTitle(destination.name), isPresented: Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } }), presenting: model.failure) { failure in
            Button("Try again") {
                switch failure {
                case .collect: Task { await model.collect() }
                case .remove: model.remove(name: destination.name)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: { failure in
            switch failure {
            case .collect: Text("Nothing was saved and your passport is unchanged. Your stamp stays where it was.")
            case .remove: Text("Nothing was changed. Your passport is the same as before.")
            }
        }
    }

    private func failureTitle(_ name: String) -> LocalizedStringKey {
        model.failure == .remove ? "\(name) was not removed" : "\(name) was not added"
    }

    private func removeMessage(_ name: String, verified: Bool) -> Text {
        verified
            ? Text("\(name) leaves your passport and your counts. Your memories and trips stay as they are. Its verified visit is removed too, so collecting it again would not be verified.")
            : Text("\(name) leaves your passport and your counts. Your memories and trips stay as they are.")
    }

    // MARK: Poster

    private func poster(_ destination: Destination, design: StampDesign?, state: StampDetailState, stamp: CollectedStamp?, layout: StageLayout, u: CGFloat) -> some View {
        ZStack(alignment: .top) {
            PosterBackground()
            StampStageLayer(name: destination.name, countryName: destination.countryName, design: design, state: state, collectedAt: stamp?.collectedAt, layout: layout,
                            postmarkHidden: design.map { model.isPostmarkHidden(stampID: $0.id) } ?? false,
                            showsSeal: !sealPress || sealLanded, sealScale: sealLanded ? 1 : 1.5, sealOpacity: sealLanded ? 1 : 0)
                .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.4, dampingFraction: 0.75), value: state)
            if sealPress, !sealLanded, !reduceMotion {
                Circle().strokeBorder(Color(hex: 0xC99432).opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [4, 4])).frame(width: 120 * u, height: 120 * u)
                    .position(layout.sealCenter).allowsHitTesting(false)
            }
            heroButtons(destination, state: state, stamp: stamp, extra: layout.extra, u: u)
        }
        .frame(width: layout.width, height: 470 * u + layout.extra)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func heroButtons(_ destination: Destination, state: StampDetailState, stamp: CollectedStamp?, extra: CGFloat, u: CGFloat) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16 * u, weight: .semibold)).foregroundStyle(HomeColor.cream).frame(width: 40 * u, height: 40 * u)
                    .posterGlass(Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(Text("Back")).accessibilityIdentifier("stamp-back")
            Spacer()
            moreMenu(destination, state: state, stamp: stamp) {
                Image(systemName: "ellipsis").font(.system(size: 16 * u, weight: .semibold)).foregroundStyle(HomeColor.cream).frame(width: 40 * u, height: 40 * u)
                    .posterGlass(Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 22 * u).padding(.top, 60 * u + extra).frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func moreMenu<MenuLabel: View>(_ destination: Destination, state: StampDetailState, stamp: CollectedStamp?, id: String = "stamp-more", @ViewBuilder label: () -> MenuLabel) -> some View {
        Menu {
            Button { env.router.push(.destination(destinationID)) } label: { Label("Destination details", systemImage: "mappin.and.ellipse") }
                .accessibilityIdentifier("stamp-menu-destination")
            if state.isCollected {
                Button { toggleFavorite(stamp) } label: { Label(stamp?.isFavorite == true ? "Remove from favorites" : "Add to favorites", systemImage: stamp?.isFavorite == true ? "heart.slash" : "heart") }
                    .accessibilityIdentifier("stamp-menu-favorite")
                Button(role: .destructive) { confirmRemove = true } label: { Label("Remove stamp", systemImage: "trash") }
                    .accessibilityIdentifier("stamp-menu-remove")
            }
        } label: { label() }
        .accessibilityLabel(Text("More")).accessibilityIdentifier(id)
    }

    private func moreMenu(_ destination: Destination, state: StampDetailState, stamp: CollectedStamp?) -> some View {
        moreMenu(destination, state: state, stamp: stamp, id: "stamp-bar-more") {
            Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink).frame(width: 42, height: 42)
                .background(HomeColor.card, in: Circle()).overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
    }

    // MARK: The reveal

    @ViewBuilder
    private func revealLayer(_ destination: Destination, design: StampDesign?, layout: StageLayout, safeTop: CGFloat) -> some View {
        if let payload = model.reveal {
            CollectionRevealView(name: destination.name, countryName: destination.countryName, categoryTitle: destination.category.singularTitle, design: design,
                                 payload: payload, completedTitle: payload.completedCollectionID.flatMap { passport.catalog.collection(id: $0)?.title },
                                 morphs: true, layout: layout, postmarkHidden: design.map { model.isPostmarkHidden(stampID: $0.id) } ?? false,
                                 canAddMemory: true,
                                 onAddMemory: { model.reveal = nil; Task { try? await Task.sleep(for: .milliseconds(150)); showMemoryEditor = true } },
                                 onDone: { model.reveal = nil })
                .ignoresSafeArea()
                .transition(.opacity)
        }
    }

    // MARK: Verify: the gold seal presses on

    private func playSealPress() {
        sealPress = true
        env.haptics.success()
        env.toasts.show(String(localized: "Visit verified. Same stamp, now checked."), icon: .seal, duration: .seconds(2.4))
        guard !reduceMotion else { sealLanded = true; return }
        sealLanded = false
        withAnimation(.timingCurve(0.3, 1.4, 0.5, 1, duration: 0.45)) { sealLanded = true }
    }

    // MARK: Lower page

    @ViewBuilder
    private func lowerPage(_ destination: Destination, design: StampDesign?, state: StampDetailState, stamp: CollectedStamp?) -> some View {
        let summary = StampDetailDerived.summary(of: destinationID, catalog: passport.catalog, snapshot: passport.snapshot)
        let related = StampDetailDerived.related(to: destinationID, catalog: passport.catalog, snapshot: passport.snapshot)
        VStack(alignment: .leading, spacing: 30) {
            about(destination)
            ledger(destination, design: design, state: state, stamp: stamp)
            if let summary { collectionCard(summary) }
            if !related.isEmpty { relatedStamps(related, collectionID: summary?.collectionID) }
            memoriesHere(destination)
            destinationRow(destination)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func about(_ destination: Destination) -> some View {
        let text = destination.story.isEmpty ? destination.summary : destination.story
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                PassportSectionHeader(title: "About this stamp", identifier: "stamp-about-title")
                Text(text).font(.system(size: 15.5)).lineSpacing(6).foregroundStyle(HomeColor.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func ledger(_ destination: Destination, design: StampDesign?, state: StampDetailState, stamp: CollectedStamp?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PassportSectionHeader(title: "Details").padding(.bottom, 8)
            if let design, !design.edition.isEmpty { row("Edition", design.edition) }
            if state.isCollected, let stamp {
                row("Collected", stamp.collectedAt.formatted(.dateTime.day().month(.abbreviated).year()))
                ledgerRow("How") {
                    HStack(spacing: 6) {
                        Text(state.isVerified ? "Verified visit" : "By hand").font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink)
                        if state.isVerified { VerifiedSeal(size: 16) }
                    }
                }
                ledgerRow("Postmark") {
                    let hidden = design.map { model.isPostmarkHidden(stampID: $0.id) } ?? false
                    HStack(spacing: 10) {
                        Text("Show on my stamp").font(.system(size: 14.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                        Toggle("Show on my stamp", isOn: Binding(get: { !hidden }, set: { on in if let design { model.setPostmarkHidden(!on, stampID: design.id) } }))
                            .labelsHidden().tint(HomeColor.cta).accessibilityIdentifier("stamp-postmark-switch")
                    }
                }
                if !trips.isEmpty {
                    ledgerRow("Trip") {
                        Picker("Trip", selection: Binding(get: { stamp.tripID }, set: { setTrip($0) })) {
                            Text("None").tag(UUID?.none)
                            ForEach(trips) { Text($0.title).tag(UUID?.some($0.id)) }
                        }
                        .pickerStyle(.menu).labelsHidden().tint(HomeColor.label)
                    }
                }
                ledgerRow("Note") {
                    Button { showNote = true } label: {
                        Text(env.store.stamp(forDestination: destinationID)?.caption ?? String(localized: "Add a note")).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(HomeColor.label).lineLimit(1).frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("stamp-note")
                }
            } else {
                row("Category", destination.category.singularTitle)
            }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        ledgerRow(label) { Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink).multilineTextAlignment(.trailing) }
    }

    private func ledgerRow<Value: View>(_ label: LocalizedStringKey, @ViewBuilder _ value: () -> Value) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return VStack(spacing: 0) {
            layout {
                Text(label).font(.system(size: 14.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                value()
            }
            .frame(minHeight: 44).padding(.vertical, 1)
            DottedRule()
        }
    }

    // MARK: Collection and related

    private func collectionCard(_ s: StampCollectionSummary) -> some View {
        Button { env.router.push(.collection(s.collectionID)) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(.system(size: 16.5, weight: .semibold)).foregroundStyle(HomeColor.ink)
                        Text("\(s.have) of \(s.total) collected").font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3)
                }
                progressBar(have: s.have, total: s.total).accessibilityHidden(true)
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(HomeColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore).accessibilityLabel(Text("\(s.title), \(s.have) of \(s.total) collected")).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("stamp-collection-card")
    }

    /// One segment per stamp up to 12, a continuous bar above that. Collected stamps only.
    @ViewBuilder
    private func progressBar(have: Int, total: Int) -> some View {
        if total > 0, total <= 12 {
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5).fill(i < have ? HomeColor.cta : PassportColor.quiet).overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(i < have ? .clear : PassportColor.cardLine, lineWidth: 1))
                        .frame(height: 9)
                }
            }
        } else {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PassportColor.quiet).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                    Capsule().fill(HomeColor.cta).frame(width: total == 0 ? 0 : geo.size.width * CGFloat(have) / CGFloat(total))
                }
            }
            .frame(height: 9)
        }
    }

    private func relatedStamps(_ related: [StampRelatedItem], collectionID: String?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            PassportSectionHeader(title: "Related stamps", identifier: "stamp-related-title", actionTitle: collectionID == nil ? nil : "View all", actionIdentifier: "stamp-related-all") {
                if let collectionID { env.router.push(.collection(collectionID)) }
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(HStackLayout(alignment: .top, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
            ScrollView(.horizontal, showsIndicators: false) {
                layout {
                    ForEach(related) { relatedCell($0).frame(width: typeSize.isAccessibilitySize ? 150 : nil).frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity) }
                }
                .frame(minWidth: typeSize.isAccessibilitySize ? nil : 354)
            }
            .scrollDisabled(!typeSize.isAccessibilitySize)
        }
    }

    private func relatedCell(_ item: StampRelatedItem) -> some View {
        let design = passport.catalog.stamp(forDestination: item.destinationID)
        return Button { env.router.push(.stamp(item.destinationID)) } label: {
            VStack(spacing: 6) {
                DiscoverStamp(design: design, name: item.name, aspect: 0.75, lifted: item.state.isCollected)
                    .frame(width: 62).saturation(item.state.isCollected ? 1 : 0.6).opacity(item.state.isCollected ? 1 : 0.8)
                    .overlay(alignment: .topTrailing) { if item.state.isVerified { VerifiedSeal(size: 24).offset(x: 10, y: -8) } }
                    .padding(.bottom, 2)
                Text(item.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(1)
                Text(relatedState(item.state)).font(.system(size: 11.5, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore).accessibilityLabel(Text("\(item.name), \(relatedState(item.state).lowercased())")).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("stamp-related-\(item.destinationID)")
    }

    private func relatedState(_ state: StampDetailState) -> String {
        switch state {
        case .collectedVerified: String(localized: "Verified")
        case .collectedManual: String(localized: "Collected")
        case .wishlisted: String(localized: "Wishlisted")
        case .notCollected: String(localized: "Not collected")
        }
    }

    // MARK: Memories, destination

    @ViewBuilder
    private func memoriesHere(_ destination: Destination) -> some View {
        if let newest = memories.first {
            VStack(alignment: .leading, spacing: 18) {
                PassportSectionHeader(title: "Memories here", identifier: "stamp-memories-title")
                HStack(spacing: 0) {
                    Button { openMemories(newest) } label: {
                        HStack(spacing: 14) {
                            Group {
                                if let first = newest.photoFilenames.first { MemoryPhoto(filename: first, maxPixel: 200, radius: 14) }
                                else { Text("“").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(HomeColor.cta).frame(maxWidth: .infinity, maxHeight: .infinity).background(PassportColor.quiet, in: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                            }
                            .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MemoryItem(newest).displayTitle()).memoryFont(16.5, .semibold, serif: true, relativeTo: .headline).foregroundStyle(HomeColor.ink).lineLimit(1)
                                Text("^[\(memories.count) memory](inflect: true) at \(destination.name)").font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2)
                            }
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("stamp-memories-row")
                    Button { showMemoryEditor = true } label: {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(HomeColor.label).frame(width: 34, height: 34)
                            .background(PassportColor.accentTint, in: Circle()).overlay(Circle().strokeBorder(PassportColor.accentBorder, lineWidth: 1))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel(Text("Add memory")).accessibilityIdentifier("stamp-memories-add")
                }
                .padding(.horizontal, 16).padding(.vertical, 15).background(HomeColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
            }
        }
    }

    private func openMemories(_ newest: MemoryEntry) {
        if memories.count == 1 { env.router.push(.memory(newest.id)) }
        else {
            // Several memories: the Memories tab, filtered to this place (the filtered timeline cannot be pushed on this stack).
            MemoryNavigation.shared.pendingPlaceID = destinationID
            env.router.select(.memories)
            env.router.popToRoot(.memories)
        }
    }

    private func destinationRow(_ destination: Destination) -> some View {
        Button { env.router.push(.destination(destinationID)) } label: {
            HStack(spacing: 14) {
                Image(systemName: "mappin").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.label).frame(width: 38, height: 38)
                    .background(PassportColor.accentTint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(destination.name), \(destination.countryName)").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(2)
                    Text("Destination details").font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3)
            }
            .padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 68).background(HomeColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1)).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier("stamp-destination-row")
    }

    // MARK: Small writes

    private func toggleFavorite(_ stamp: CollectedStamp?) {
        guard let stamp else { return }
        do { try env.store.setFavorite(destinationID: destinationID, !stamp.isFavorite); env.haptics.lightImpact() } catch {}
    }

    private func setTrip(_ id: UUID?) { do { try env.store.setTrip(destinationID: destinationID, tripID: id) } catch {} }
}

/// The bar that fades in as the stage leaves: the place name and solid back and more circles.
struct StampDetailChrome<MenuContent: View>: View {
    let scroll: StampScrollState
    let title: String
    let barHeight: CGFloat
    let safeTop: CGFloat
    let onBack: () -> Void
    @ViewBuilder var menu: () -> MenuContent

    var body: some View {
        // Starts to appear at about 290 pt of scroll and is fully there by about 370 pt.
        let opacity = min(1, max(0, (scroll.offset - 290) / 80))
        ZStack {
            Text(title).font(.system(size: 18, weight: .bold)).tracking(-0.02 * 18).foregroundStyle(HomeColor.ink).lineLimit(1)
                .padding(.horizontal, 70).accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink).frame(width: 42, height: 42)
                        .background(HomeColor.card, in: Circle()).overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1)).shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(Text("Back")).accessibilityIdentifier("stamp-bar-back")
                Spacer()
                menu()
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, safeTop - 2).padding(.bottom, 4).frame(maxWidth: .infinity).frame(height: barHeight + 2, alignment: .bottom)
        .cardGlass(Rectangle(), tint: 0.965, lined: false)
        .overlay(alignment: .bottom) { Rectangle().fill(PassportColor.cardLine).frame(height: 1) }
        .opacity(opacity).allowsHitTesting(opacity > 0.6)
        .frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea(edges: .top)
        .accessibilityHidden(opacity < 0.6)
    }
}

/// A line to remember a stamp by. Private: it never appears in anything that is shared.
struct StampNoteSheet: View {
    let destinationID: String
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("A line to remember this stamp by", text: $text, axis: .vertical).lineLimit(2...6).padding(14)
                    .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1)).accessibilityIdentifier("stamp-note-field")
                Label("Private. It never appears in anything you share.", systemImage: "lock").font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                if failed { Text("Your note couldn’t be saved. Nothing was changed.").font(.system(size: 13)).foregroundStyle(SQColor.error) }
                Spacer()
            }
            .padding(20).background(HomeColor.page.ignoresSafeArea()).navigationTitle("Note").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.accessibilityIdentifier("stamp-note-save") }
            }
            .onAppear { text = env.store.stamp(forDestination: destinationID)?.caption ?? "" }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        do { try env.store.setCaption(destinationID: destinationID, text); dismiss() } catch { failed = true }
    }
}
