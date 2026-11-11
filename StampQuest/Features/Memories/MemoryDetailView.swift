import SwiftUI
import SwiftData

/// A memory: a full-bleed photo carousel (or a calm header when there are none), a paper sheet with the date, title, place
/// card, text and tags. Deleting asks first and says what stays.
struct MemoryDetailView: View {
    let memoryID: UUID

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @Query private var found: [MemoryEntry]
    @State private var model: MemoriesViewModel?
    @State private var page = 0
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var viewer: ViewerStart?

    private struct ViewerStart: Identifiable { let id = UUID(); let index: Int }

    init(memoryID: UUID) {
        self.memoryID = memoryID
        _found = Query(filter: #Predicate<MemoryEntry> { $0.id == memoryID })
    }

    var body: some View {
        Group {
            if let entry = found.first { content(MemoryItem(entry), entry: entry) }
            else { EmptyStateView(title: "Memory not found", message: "It may have been deleted.", systemImage: "heart.text.square").sqScreenBackground() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { if model == nil { model = MemoriesViewModel(env: env) } }
    }

    private func content(_ item: MemoryItem, entry: MemoryEntry) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    if item.hasPhotos { hero(item) } else { Color.clear.frame(height: 120) }
                    paper(item).offset(y: item.hasPhotos ? -24 : 0).padding(.bottom, item.hasPhotos ? -24 : 0)
                }
            }
            .background(HomeColor.page.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            controls(item, entry: entry)
        }
        .background(HomeColor.page.ignoresSafeArea())
        .sheet(isPresented: $showEditor) { MemoryEditorSheet(memory: entry) }
        .fullScreenCover(item: $viewer) { PhotoViewer(filenames: item.photoFilenames, start: $0.index) }
        .alert("Delete this memory?", isPresented: $confirmDelete) {
            Button("Delete memory", role: .destructive) { if model?.delete(item.id) == true { dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { MemoryDeleteCopy.message(for: item, catalog: passport.catalog) }
        .alert("Something went wrong", isPresented: Binding(get: { model?.errorMessage != nil }, set: { if !$0 { model?.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model?.errorMessage ?? "") }
    }

    // MARK: Hero

    private func hero(_ item: MemoryItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $page) {
                ForEach(Array(item.photoFilenames.enumerated()), id: \.element) { index, name in
                    MemoryPhoto(filename: name, maxPixel: 2048, radius: 0, spokenLabel: String(localized: "Photo \(index + 1) of \(item.photoFilenames.count)"))
                        .frame(maxWidth: .infinity).frame(height: 340).clipped().contentShape(Rectangle())
                        .onTapGesture { viewer = ViewerStart(index: index) }
                        .accessibilityAddTraits(.isButton).accessibilityHint(Text("Opens the photo full screen"))
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 340)
            .overlay(alignment: .top) { LinearGradient(colors: [.black.opacity(0.42), .clear], startPoint: .top, endPoint: .bottom).frame(height: 130).allowsHitTesting(false) }
            if item.photoFilenames.count > 1 {
                HStack(spacing: 5) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 11, weight: .semibold))
                    Text("\(page + 1) of \(item.photoFilenames.count)").font(.system(size: 12, weight: .bold)).monospacedDigit()
                }
                .foregroundStyle(HomeColor.cream).padding(.horizontal, 12).frame(minHeight: 28).posterGlass(Capsule()).padding(.trailing, 16).padding(.bottom, 40)
                .accessibilityElement(children: .ignore).accessibilityLabel(Text("Photo \(page + 1) of \(item.photoFilenames.count)"))
            }
        }
    }

    // MARK: Controls

    private func controls(_ item: MemoryItem, entry: MemoryEntry) -> some View {
        let onPhoto = item.hasPhotos
        return GeometryReader { proxy in
            HStack(spacing: 8) {
                circle("chevron.left", label: "Back", id: "memory-back", onPhoto: onPhoto) { dismiss() }
                Spacer()
                circle("pencil", label: "Edit memory", id: "edit-memory", onPhoto: onPhoto) { showEditor = true }
                Menu {
                    Button { showEditor = true } label: { Label("Edit memory", systemImage: "pencil") }.accessibilityIdentifier("menu-edit-memory")
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete memory", systemImage: "trash") }.accessibilityIdentifier("delete-memory")
                } label: {
                    circleLabel("ellipsis", onPhoto: onPhoto)
                }
                .accessibilityLabel(Text("More")).accessibilityIdentifier("memory-more")
            }
            .padding(.horizontal, 16).padding(.top, max(proxy.safeAreaInsets.top, 44) + 4)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func circle(_ symbol: String, label: LocalizedStringKey, id: String, onPhoto: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { circleLabel(symbol, onPhoto: onPhoto) }
            .buttonStyle(.plain).accessibilityLabel(Text(label)).accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func circleLabel(_ symbol: String, onPhoto: Bool) -> some View {
        let icon = Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
        Group {
            if onPhoto { icon.foregroundStyle(HomeColor.cream).frame(width: 42, height: 42).posterGlass(Circle()) }
            else { icon.foregroundStyle(HomeColor.ink).frame(width: 42, height: 42).background(PassportColor.quiet, in: Circle()).overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1)) }
        }
        .frame(width: 44, height: 44).contentShape(Rectangle())
    }

    // MARK: Paper

    private func paper(_ item: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.effectiveDate.memoryLongDate()).memoryFont(13, .semibold, relativeTo: .footnote).foregroundStyle(HomeColor.label).padding(.top, 30)
            Text(item.displayTitle()).memoryFont(31, .semibold, serif: true, relativeTo: .largeTitle).lineSpacing(5).foregroundStyle(HomeColor.ink)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8).accessibilityAddTraits(.isHeader).accessibilityIdentifier("memory-detail-title")
            placeCard(item).padding(.top, 24)
            if !item.text.isEmpty {
                Text(item.text).memoryFont(17.5, .regular, serif: true, relativeTo: .body).lineSpacing(8).foregroundStyle(HomeColor.ink)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true).padding(.top, 22)
            }
            if !item.tags.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        Button {
                            MemoryNavigation.shared.pendingTag = tag
                            env.router.popToRoot(.memories)
                        } label: { MemoryTagChip(text: tag).frame(minHeight: 44).contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityLabel(Text("Tag \(tag)")).accessibilityHint(Text("Shows memories with this tag"))
                    }
                }
                .padding(.top, 18)
            }
            DottedRule().padding(.top, 30)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock").font(.system(size: 12, weight: .semibold))
                Text("Private by default. Left out of anything you share unless you choose to include it.").font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(HomeColor.sub).padding(.top, 14).accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 20).padding(.bottom, 60).frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
        .background(alignment: .top) {
            if item.hasPhotos {
                UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30).fill(HomeColor.page).shadow(color: .black.opacity(0.14), radius: 14, y: -6).frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func placeCard(_ item: MemoryItem) -> some View {
        let state = MemoryDerived.placeState(of: item, catalog: passport.catalog, snapshot: passport.snapshot)
        if state != .noPlace, let id = item.destinationID {
            Button { if state != .removedFromCatalog { env.router.push(.destination(id)) } } label: {
                HStack(spacing: 14) {
                    if let place = passport.item(id: id) { DiscoverStamp(design: place.design, name: place.destination.name, lifted: false).frame(width: 34).rotationEffect(.degrees(-3)) }
                    else { DiscoverDashedSlot(width: 34, height: 44) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(passport.catalog.destination(id: id)?.name ?? String(localized: "Place no longer in the catalog")).memoryFont(16.5, .semibold, relativeTo: .headline)
                            .foregroundStyle(HomeColor.ink).lineLimit(2)
                        stateLine(state)
                    }
                    Spacer(minLength: 8)
                    if state != .removedFromCatalog { Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3) }
                }
                .padding(.horizontal, 18).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 70)
                .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(state == .removedFromCatalog).accessibilityIdentifier("memory-place-card")
        }
    }

    @ViewBuilder
    private func stateLine(_ state: MemoryPlaceState) -> some View {
        HStack(spacing: 6) {
            switch state {
            case .verified:
                VerifiedSeal(size: 17)
                Text("Verified visit").foregroundStyle(HomeColor.ink).fontWeight(.semibold)
            case .collected:
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(HomeColor.label)
                Text("In your passport").foregroundStyle(HomeColor.label).fontWeight(.semibold)
            case .notInPassport:
                Text("Not in your passport yet").foregroundStyle(HomeColor.sub)
            case .removedFromCatalog:
                Text("Place no longer in the catalog").foregroundStyle(HomeColor.sub)
            case .noPlace:
                EmptyView()
            }
        }
        .memoryFont(12.5, .medium, relativeTo: .caption)
    }
}

/// A simple full-screen photo viewer: black background, swipe between photos, pinch to zoom, a Close button.
struct PhotoViewer: View {
    let filenames: [String]
    let start: Int
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var zoom: CGFloat = 1

    init(filenames: [String], start: Int) {
        self.filenames = filenames
        self.start = start
        _index = State(initialValue: start)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(filenames.enumerated()), id: \.element) { i, name in
                    MemoryPhoto(filename: name, maxPixel: 2048, radius: 0, spokenLabel: String(localized: "Photo \(i + 1) of \(filenames.count)"), fit: true)
                        .scaleEffect(i == index ? zoom : 1)
                        .gesture(MagnifyGesture().onChanged { zoom = max(1, min(4, $0.magnification)) }.onEnded { _ in withAnimation(.spring) { zoom = 1 } })
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)).ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain).padding(16).accessibilityLabel(Text("Close")).accessibilityIdentifier("photo-viewer-close")
        }
    }
}
