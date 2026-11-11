import SwiftUI

// MARK: - Renderable artwork

enum ShareStyle: String, CaseIterable, Identifiable {
    case paper, color

    var id: String { rawValue }
    var title: LocalizedStringKey { self == .paper ? "Paper" : "Colour" }
}

/// The picture that gets shared: the stamp, the public place name, and optionally the
/// date. Nothing private can appear here by construction: this view is never given
/// notes, photos, captions, coordinates or trip names.
struct ShareableStampImage: View {
    let design: StampDesign
    let placeName: String
    let subtitle: String
    let date: Date?
    let isVerified: Bool
    let style: ShareStyle

    static let size = CGSize(width: 540, height: 675)

    var body: some View {
        ZStack {
            switch style {
            case .paper: Color(hex: 0xF7F2E8)
            case .color: design.borderTint.color.opacity(0.28).background(Color(hex: 0xF7F2E8))
            }
            VStack(spacing: 22) {
                Spacer(minLength: 24)
                PassportStamp(design: design,
                              postmark: date.map { (placeName, $0, isVerified ? .verified : .collected) })
                    .frame(width: 300)
                    .rotationEffect(.degrees(-2))
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
                VStack(spacing: 6) {
                    Text(placeName).font(.system(size: 40, weight: .semibold, design: .serif)).foregroundStyle(Color(hex: 0x252724))
                    Text(subtitle).font(.system(size: 20)).foregroundStyle(Color(hex: 0x5C5B54))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                Spacer(minLength: 12)
                VStack(spacing: 2) {
                    Text("STAMPQUEST").font(.system(size: 14, weight: .bold, design: .serif)).tracking(4).foregroundStyle(Color(hex: 0x934B2B))
                    Text("Your world, one stamp at a time.").font(.system(size: 13)).foregroundStyle(Color(hex: 0x6B685F))
                }
                .padding(.bottom, 26)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }
}

struct ShareablePassportPage: View {
    /// The owner's name, shown under the title. Empty when the person gave none.
    var ownerName = ""
    let items: [(design: StampDesign, name: String, date: Date?, verified: Bool)]
    let stampCount: Int
    let countryCount: Int

    static let size = CGSize(width: 540, height: 720)

    var body: some View {
        ZStack {
            Color(hex: 0xF7F2E8)
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("MY PASSPORT").font(.system(size: 26, weight: .bold, design: .serif)).tracking(5).foregroundStyle(Color(hex: 0x934B2B))
                    if !ownerName.isEmpty { Text(ownerName).font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color(hex: 0x252724)) }
                    Text("\(stampCount) \(stampCount == 1 ? "stamp" : "stamps") · \(countryCount) \(countryCount == 1 ? "country" : "countries")")
                        .font(.system(size: 16)).foregroundStyle(Color(hex: 0x5C5B54))
                }
                .padding(.top, 34)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 18) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        PassportStamp(design: item.design, postmark: item.date.map { (item.name, $0, item.verified ? .verified : .collected) })
                            .rotationEffect(.degrees(Double(index % 5) - 2))
                    }
                }
                .padding(.horizontal, 34)
                Spacer(minLength: 0)
                Text("STAMPQUEST").font(.system(size: 13, weight: .bold, design: .serif)).tracking(4).foregroundStyle(Color(hex: 0x934B2B)).padding(.bottom, 22)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }
}

@MainActor
func renderShareImage<V: View>(_ view: V, scale: CGFloat = 3) -> UIImage? {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    return renderer.uiImage
}

private struct SharePrivacyNote: View {
    var body: some View {
        Label("Only the artwork, the place name and (if you choose) the date are shared. Never your notes, photos or location.", systemImage: "lock.shield")
            .font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
    }
}

// MARK: - Stamp share sheet

struct ShareStampSheet: View {
    let item: DestinationItem
    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @State private var includeDate = true
    @State private var style: ShareStyle = .paper
    @State private var image: UIImage?
    @State private var failed = false

    private var stamp: CollectedStamp? { passport.snapshot.collectedStamp(forDestination: item.id) }

    private var artwork: ShareableStampImage {
        ShareableStampImage(design: item.design, placeName: item.destination.name, subtitle: item.destination.subtitle,
                            date: includeDate ? (stamp?.verifiedAt ?? stamp?.collectedAt) : nil,
                            isVerified: stamp?.isVerified ?? false, style: style)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SQSpace.md) {
                    Group {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                                .accessibilityLabel("Preview of the image you’re about to share")
                        } else if failed {
                            InlineErrorView(title: "Couldn’t prepare the image", message: "Nothing was shared. Please try again.") { render() }
                        } else {
                            LoadingStateView(message: "Preparing preview…")
                        }
                    }
                    .frame(maxHeight: 460)
                    Toggle("Include collection date", isOn: $includeDate)
                    Picker("Style", selection: $style) { ForEach(ShareStyle.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    SharePrivacyNote()
                    if let image {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("\(item.destination.name) stamp", image: Image(uiImage: image))) {
                            Label("Share image", systemImage: "square.and.arrow.up").font(SQFont.headline).frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.sqPrimary)
                        .accessibilityIdentifier("share-image")
                    }
                }
                .padding(SQSpace.screenMargin)
            }
            .sqScreenBackground()
            .navigationTitle("Share stamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task(id: "\(includeDate)-\(style.rawValue)") { render() }
        .presentationDetents([.large])
    }

    private func render() {
        failed = false
        if let rendered = renderShareImage(artwork) { image = rendered } else { image = nil; failed = true }
    }
}

// MARK: - Passport page share sheet

struct SharePassportPageSheet: View {
    var ownerName = ""
    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @State private var scope: Scope = .latest
    @State private var image: UIImage?
    @State private var failed = false

    enum Scope: String, CaseIterable, Identifiable {
        case latest, favorites, verified
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .latest: "Latest"
            case .favorites: "Favourites"
            case .verified: "Verified"
            }
        }
    }

    private var chosen: [CollectedStamp] {
        let all = passport.snapshot.stamps
        switch scope {
        case .latest: return Array(all.prefix(9))
        case .favorites: return Array(all.filter(\.isFavorite).prefix(9))
        case .verified: return Array(all.filter(\.isVerified).prefix(9))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SQSpace.md) {
                    Picker("Which stamps", selection: $scope) { ForEach(Scope.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    Group {
                        if chosen.isEmpty {
                            EmptyStateView(title: "No stamps in this selection", message: "Pick a different set, or mark some stamps as favourites first.", systemImage: "square.grid.3x3")
                        } else if let image {
                            Image(uiImage: image).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                                .accessibilityLabel("Preview of the passport page you’re about to share")
                        } else if failed {
                            InlineErrorView(title: "Couldn’t prepare the page", message: "Nothing was shared. Please try again.") { render() }
                        } else {
                            LoadingStateView(message: "Preparing preview…")
                        }
                    }
                    .frame(maxHeight: 480)
                    SharePrivacyNote()
                    Text("Notes and photos are never included.").font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
                    if let image, !chosen.isEmpty {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("My StampQuest passport", image: Image(uiImage: image))) {
                            Label("Share passport page", systemImage: "square.and.arrow.up").font(SQFont.headline).frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.sqPrimary)
                    }
                }
                .padding(SQSpace.screenMargin)
            }
            .sqScreenBackground()
            .navigationTitle("Share passport page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task(id: scope) { render() }
        .presentationDetents([.large])
    }

    private func render() {
        failed = false
        image = nil
        guard !chosen.isEmpty else { return }
        // The export model has no field for a note, caption, memory or photo: only stamps, counts and the owner's name.
        let entries = chosen.map { PassportEntry(stamp: $0, destination: passport.catalog.destination(id: $0.destinationID), design: passport.catalog.stamp(forDestination: $0.destinationID)) }
        let export = PassportExportModel.make(entries: entries, metrics: PassportMetrics.compute(snapshot: passport.snapshot, catalog: passport.catalog), ownerName: ownerName)
        let page = ShareablePassportPage(ownerName: export.ownerName,
                                         items: export.items.map { (design: $0.design, name: $0.name, date: Optional($0.date), verified: $0.isVerified) },
                                         stampCount: export.stampCount, countryCount: export.countryCount)
        if let rendered = renderShareImage(page) { image = rendered } else { failed = true }
    }
}
