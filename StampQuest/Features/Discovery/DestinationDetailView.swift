import SwiftUI
import SwiftData

extension Destination {
    /// "48.8584° N, 2.2945° E": a reference point for the place, not a user location.
    var coordinateText: String {
        let lat = abs(latitude).formatted(.number.precision(.fractionLength(4)))
        let lon = abs(longitude).formatted(.number.precision(.fractionLength(4)))
        return "\(lat)° \(latitude >= 0 ? "N" : "S"), \(lon)° \(longitude >= 0 ? "E" : "W")"
    }
}

struct DestinationDetailView: View {
    let destinationID: String

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @State private var showVerify = false
    @State private var showMemoryEditor = false
    @State private var showShare = false
    @State private var saveError: String?

    var body: some View {
        Group {
            if let item = passport.item(id: destinationID) {
                content(item)
            } else {
                EmptyStateView(title: "This place isn’t available", message: "It may have been removed from the catalog. Your memories and stamps about it are safe.", systemImage: "questionmark.diamond")
                    .padding(.top, SQSpace.xxl)
            }
        }
        .sqScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { env.preferences.noteViewed(destinationID) }
        .alert("Couldn’t save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveError ?? "") }
    }

    @ViewBuilder
    private func content(_ item: DestinationItem) -> some View {
        let d = item.destination
        ScrollView {
            VStack(spacing: 0) {
                hero(item)
                VStack(alignment: .leading, spacing: SQSpace.lg) {
                    titleBlock(item)
                    actions(item)
                    VStack(alignment: .leading, spacing: SQSpace.sm) {
                        Text(d.summary).font(SQFont.headline).foregroundStyle(SQColor.textPrimary)
                        Text(d.story).font(SQFont.story).foregroundStyle(SQColor.textSecondary).lineSpacing(4)
                    }
                    facts(item)
                    collections(item)
                    DestinationMemoriesSection(destinationID: d.id) { showMemoryEditor = true }
                    related(item)
                }
                .padding(.horizontal, SQSpace.screenMargin)
                .padding(.top, SQSpace.lg)
                .padding(.bottom, SQSpace.xxl)
                .sqReadableWidth()
            }
        }
        .navigationTitle(d.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if item.state.isInPassport {
                    Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share stamp")
                } else {
                    Button { toggleWishlist(item) } label: {
                        Image(systemName: item.state == .wishlisted ? "heart.fill" : "heart")
                            .foregroundStyle(item.state == .wishlisted ? SQColor.wishlist : SQColor.textPrimary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(item.state == .wishlisted ? "Remove from wishlist" : "Add to wishlist")
                    .accessibilityIdentifier("wishlist-toolbar")
                }
            }
        }
        .sheet(isPresented: $showVerify) { VerifyVisitSheet(item: item) }
        .sheet(isPresented: $showMemoryEditor) { MemoryEditorSheet(prefilledDestinationID: d.id) }
        .sheet(isPresented: $showShare) { ShareStampSheet(item: item) }
    }

    // MARK: Hero

    private func hero(_ item: DestinationItem) -> some View {
        ZStack {
            LinearGradient(colors: [item.design.borderTint.color.opacity(0.30), SQColor.background], startPoint: .top, endPoint: .bottom)
            PassportStamp(design: item.design, presentation: .full,
                          postmark: item.state.isInPassport ? stampPostmark(item) : nil)
                .frame(maxWidth: 210)
                .padding(.horizontal, 60)
                .padding(.vertical, SQSpace.lg)
                .rotationEffect(.degrees(-2))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        }
        .frame(maxWidth: .infinity)
    }

    private func stampPostmark(_ item: DestinationItem) -> (place: String, date: Date, kind: PostmarkKind)? {
        guard let stamp = passport.snapshot.collectedStamp(forDestination: item.id) else { return nil }
        return (item.destination.name, stamp.verifiedAt ?? stamp.collectedAt, stamp.isVerified ? .verified : .collected)
    }

    private func titleBlock(_ item: DestinationItem) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            Text(item.destination.category.singularTitle).sqEyebrow()
            Text(item.destination.name)
                .font(SQFont.display)
                .foregroundStyle(SQColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(item.destination.landmark.caseInsensitiveCompare(item.destination.name) == .orderedSame
                 ? item.destination.countryName : "\(item.destination.landmark) · \(item.destination.countryName)")
                .font(SQFont.body)
                .foregroundStyle(SQColor.textSecondary)
            StampCollectionStateBadge(state: item.state)
                .padding(.top, SQSpace.xxs)
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ item: DestinationItem) -> some View {
        VStack(spacing: SQSpace.sm) {
            switch item.state {
            case .notCollected, .wishlisted:
                PrimaryActionButton(title: "Collect stamp", systemImage: "plus.circle") { collect(item) }
                    .accessibilityIdentifier("collect-button")
                HStack(spacing: SQSpace.sm) {
                    SecondaryActionButton(title: item.state == .wishlisted ? "Wishlisted" : "Wishlist",
                                          systemImage: item.state == .wishlisted ? "heart.fill" : "heart") { toggleWishlist(item) }
                        .accessibilityIdentifier("wishlist-button")
                    if env.preferences.locationVerificationEnabled {
                        SecondaryActionButton(title: "Verify visit", systemImage: "location") { showVerify = true }
                            .accessibilityIdentifier("verify-button")
                    }
                }
            case .collected:
                PrimaryActionButton(title: "View in passport", systemImage: "book.closed") {
                    env.router.push(.stamp(item.id))
                }
                .accessibilityIdentifier("view-in-passport-button")
                if env.preferences.locationVerificationEnabled {
                    SecondaryActionButton(title: "Verify my visit", systemImage: "location") { showVerify = true }
                        .accessibilityIdentifier("verify-button")
                }
            case .verified:
                PrimaryActionButton(title: "View in passport", systemImage: "book.closed") {
                    env.router.push(.stamp(item.id))
                }
                .accessibilityIdentifier("view-in-passport-button")
            }
        }
    }

    private func collect(_ item: DestinationItem) {
        if let error = env.collect(item.id) { saveError = error.errorDescription }
    }

    private func toggleWishlist(_ item: DestinationItem) {
        do {
            try withAnimation(SQMotion.quick) {
                if item.state == .wishlisted { _ = try env.store.removeFromWishlist(destinationID: item.id) }
                else { _ = try env.store.addToWishlist(destinationID: item.id) }
            }
            env.haptics.lightImpact()
        } catch {
            saveError = (error as? PassportError)?.errorDescription ?? String(localized: "Your change couldn’t be saved.")
        }
    }

    // MARK: Facts

    private func facts(_ item: DestinationItem) -> some View {
        let d = item.destination
        return VStack(alignment: .leading, spacing: SQSpace.sm) {
            Text("At a glance").font(SQFont.section).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                factRow("Country", "\(CountryInfo.flag(for: d.countryCode)) \(d.countryName)", symbol: "flag")
                Divider().overlay(SQColor.separator)
                factRow("Region", d.region.title, symbol: "globe")
                Divider().overlay(SQColor.separator)
                factRow("Category", d.category.singularTitle, symbol: d.category.symbolName)
                Divider().overlay(SQColor.separator)
                factRow("Reference point", d.coordinateText, symbol: "mappin.and.ellipse")
                Divider().overlay(SQColor.separator)
                factRow("Verification range", Measurement(value: d.verificationRadius, unit: UnitLength.meters)
                    .formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(d.verificationRadius >= 1000 ? 1 : 0)))),
                        symbol: "scope")
            }
            .padding(.horizontal, SQSpace.md)
            .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
            Button { env.router.push(.country(d.countryCode)) } label: {
                Text("More from \(d.countryName)").font(SQFont.subheadline.weight(.semibold))
            }
            .foregroundStyle(SQColor.accentText)
            .frame(minHeight: SQHit.minimum)
        }
    }

    private func factRow(_ label: LocalizedStringKey, _ value: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SQSpace.sm) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(SQColor.accentText).accessibilityHidden(true)
            Text(label).font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
            Spacer(minLength: SQSpace.sm)
            Text(value).font(SQFont.subheadline.weight(.medium)).foregroundStyle(SQColor.textPrimary).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, SQSpace.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: Collections & related

    @ViewBuilder
    private func collections(_ item: DestinationItem) -> some View {
        let containing = env.catalog.collections(containing: item.id)
        if !containing.isEmpty {
            VStack(alignment: .leading, spacing: SQSpace.sm) {
                Text("Part of").font(SQFont.section).accessibilityAddTraits(.isHeader)
                ForEach(containing) { collection in
                    if let progress = passport.progress(forCollection: collection.id) {
                        Button { env.router.push(.collection(collection.id)) } label: {
                            HStack(spacing: SQSpace.sm) {
                                Image(systemName: collection.symbolName)
                                    .frame(width: 36, height: 36)
                                    .background(SQColor.accent.opacity(0.15), in: Circle())
                                    .foregroundStyle(SQColor.accentText)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(collection.title).font(SQFont.headline).foregroundStyle(SQColor.textPrimary)
                                    CollectionProgressView(progress: progress, compact: true)
                                }
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(SQColor.textTertiary)
                            }
                            .padding(SQSpace.sm)
                            .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func related(_ item: DestinationItem) -> some View {
        let others = env.catalog.related(to: item.destination).compactMap(passport.item)
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: SQSpace.sm) {
                Text("You might also like").font(SQFont.section).accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: SQSpace.sm) {
                        ForEach(others) { other in
                            Button { env.router.push(.destination(other.id)) } label: { DestinationCard(item: other, width: 160) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
        }
    }
}

/// Memories the person has written about this place, with a shortcut to add one.
struct DestinationMemoriesSection: View {
    let destinationID: String
    let onAdd: () -> Void
    @Environment(AppEnvironment.self) private var env
    @Query private var memories: [MemoryEntry]

    init(destinationID: String, onAdd: @escaping () -> Void) {
        self.destinationID = destinationID
        self.onAdd = onAdd
        _memories = Query(filter: #Predicate<MemoryEntry> { $0.destinationID == destinationID },
                          sort: [SortDescriptor(\.eventDate, order: .reverse)])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.sm) {
            SectionHeader(title: "Your memories", actionTitle: "Add", action: onAdd)
            if memories.isEmpty {
                Text("Nothing written yet. Add a note or a photo to remember this place.")
                    .font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
            } else {
                ForEach(memories.prefix(3)) { memory in
                    Button { env.router.push(.memory(memory.id)) } label: { MemoryRow(memory: memory) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}
