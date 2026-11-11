import SwiftUI

struct CollectionsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SQSpace.sm) {
                ForEach(passport.progress) { progress in
                    Button { env.router.push(.collection(progress.collection.id)) } label: {
                        CollectionCard(progress: progress, cover: passport.item(id: progress.collection.coverDestinationID), width: nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collection-\(progress.collection.id)")
                }
            }
            .padding(.horizontal, SQSpace.screenMargin)
            .padding(.bottom, SQSpace.xxl)
        }
        .sqScreenBackground()
        .navigationTitle("Collections")
    }
}

struct CollectionDetailView: View {
    let collectionID: String

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable, Identifiable {
        case all, collected, missing
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .all: "All"
            case .collected: "Collected"
            case .missing: "Missing"
            }
        }
    }

    var body: some View {
        if let progress = passport.progress(forCollection: collectionID) {
            content(progress)
        } else {
            EmptyStateView(title: "Collection not found", message: "It may have been removed from the catalog.", systemImage: "square.grid.2x2")
                .sqScreenBackground()
        }
    }

    private func content(_ progress: CollectionProgress) -> some View {
        let all = passport.items(ids: progress.collection.destinationIDs)
        let shown = all.filter {
            switch filter {
            case .all: true
            case .collected: $0.state.isInPassport
            case .missing: !$0.state.isInPassport
            }
        }
        let nextMissing = all.first { !$0.state.isInPassport }
        return ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.lg) {
                VStack(alignment: .leading, spacing: SQSpace.sm) {
                    HStack(spacing: SQSpace.sm) {
                        Image(systemName: progress.collection.symbolName)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(SQColor.accent.opacity(0.16), in: Circle())
                            .foregroundStyle(SQColor.accentText)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(progress.collection.subtitle).sqEyebrow()
                            Text(progress.collection.title).font(SQFont.display).foregroundStyle(SQColor.textPrimary).accessibilityAddTraits(.isHeader)
                        }
                    }
                    Text(progress.collection.summary).font(SQFont.story).foregroundStyle(SQColor.textSecondary)
                    CollectionProgressView(progress: progress)
                }
                if progress.isComplete { completionBanner(progress) }
                else if let next = nextMissing {
                    Button { env.router.push(.destination(next.id)) } label: {
                        HStack(spacing: SQSpace.sm) {
                            PerforatedStampView(design: next.design, presentation: .muted, showsTitle: false, isDecorative: true).frame(width: 44)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Next up").sqEyebrow()
                                Text(next.destination.name).font(SQFont.headline).foregroundStyle(SQColor.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(SQColor.textTertiary)
                        }
                        .padding(SQSpace.sm)
                        .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collection-next")
                }
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if shown.isEmpty {
                    EmptyStateView(title: filter == .collected ? "Nothing collected yet" : "All collected",
                                   message: filter == .collected ? "Collect a stamp from this set and it will appear here." : "You have every stamp in this collection.",
                                   systemImage: filter == .collected ? "tray" : "checkmark.seal")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 18, alignment: .top)], spacing: 24) {
                        ForEach(shown) { item in
                            Button { env.router.push(item.state.isInPassport ? .stamp(item.id) : .destination(item.id)) } label: {
                                StampGridItem(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("collection-stamp-\(item.id)")
                        }
                    }
                    .animation(SQMotion.standard, value: filter)
                }
            }
            .padding(.horizontal, SQSpace.screenMargin)
            .padding(.bottom, SQSpace.xxl)
        }
        .sqScreenBackground()
        .navigationTitle(progress.collection.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func completionBanner(_ progress: CollectionProgress) -> some View {
        HStack(spacing: SQSpace.sm) {
            Image(systemName: "rosette").font(.system(size: 28)).foregroundStyle(SQColor.success).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Collection complete").font(SQFont.headline).foregroundStyle(SQColor.textPrimary)
                if let date = progress.completedAt {
                    Text("Finished \(date.formatted(date: .long, time: .omitted))").font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
                }
            }
            Spacer()
        }
        .padding(SQSpace.md)
        .background(SQColor.success.opacity(0.12), in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous).strokeBorder(SQColor.success.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("collection-complete")
    }
}

/// The Wishlist: places saved for later, newest saved first. Saved is not collected, so a place that is in the passport is
/// never listed here. Removing asks nothing but offers Undo, which restores the original saved date.
struct WishlistView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @State private var model: DiscoverViewModel?

    private var items: [DestinationItem] {
        passport.snapshot.wishlist
            .sorted { $0.addedAt > $1.addedAt }
            .compactMap { passport.item(id: $0.destinationID) }
            .filter { !$0.state.isInPassport }
    }

    var body: some View {
        let items = items
        Group {
            if items.isEmpty {
                ScrollView {
                    EmptyStateView(title: "Nothing saved yet", message: "Tap the bookmark on a place to save it for later.",
                                   systemImage: "bookmark", actionTitle: "Explore places") { env.router.select(.discover); env.router.popToRoot(.discover) }
                        .padding(.top, SQSpace.xl).accessibilityIdentifier("wishlist-empty")
                }
            } else {
                List {
                    Text("^[\(items.count) place](inflect: true) saved for later").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.sub)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden).accessibilityIdentifier("wishlist-count")
                    ForEach(items) { item in
                        Button { env.router.push(.destination(item.id)) } label: { DiscoverPlaceRow(item: item) }
                            .buttonStyle(.plain)
                            .listRowBackground(SQColor.background)
                            .listRowSeparatorTint(PassportColor.cardLine)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { model?.removeFromWishlist(item.id) } label: { Label("Remove", systemImage: "bookmark.slash") }
                            }
                            .accessibilityAction(named: Text("Remove from wishlist")) { model?.removeFromWishlist(item.id) }
                            .accessibilityIdentifier("wishlist-\(item.id)")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sqScreenBackground()
        .navigationTitle("Wishlist")
        .onAppear { if model == nil { model = DiscoverViewModel(env: env) } }
        .discoverToast(env.toasts, bottomInset: 24)
        .alert("Couldn’t update", isPresented: Binding(get: { model?.errorMessage != nil }, set: { if !$0 { model?.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model?.errorMessage ?? "") }
    }
}
