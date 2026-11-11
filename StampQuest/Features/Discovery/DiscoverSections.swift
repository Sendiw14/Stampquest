import SwiftUI

extension View {
    /// The right edge of a rail fades into the page over 56 pt, so the last stamp reads as continuing.
    func discoverRailFade(_ width: CGFloat = 56) -> some View {
        mask(HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: width)
        })
    }
}

/// An empty stamp slot: a dashed outline where art is not there yet.
struct DiscoverDashedSlot: View {
    var width: CGFloat = 52
    var height: CGFloat = 70

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(HomeColor.ink3.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
            .frame(width: width, height: height).accessibilityHidden(true)
    }
}

// MARK: - Browse by interest

struct DiscoverInterestRail: View {
    let interests: [DiscoverInterest]
    let art: (DiscoverInterest) -> DestinationItem?
    let scale: CGFloat
    let landed: Bool
    let onOpen: (DiscoverInterest) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let tilts: [Double] = [-1.5, 1.2, -1.0, 1.5, -1.2, 1.0]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14 * scale) {
                ForEach(Array(interests.enumerated()), id: \.element.id) { index, interest in
                    Button { onOpen(interest) } label: {
                        DiscoverInterestTile(interest: interest, art: art(interest), tilt: Self.tilts[index % Self.tilts.count], scale: scale)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(landed || reduceMotion ? 1 : 1.1).offset(y: landed || reduceMotion ? 0 : -12).opacity(landed ? 1 : 0)
                    .animation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.5, dampingFraction: 0.72).delay(Double(index) * 0.07), value: landed)
                    .accessibilityIdentifier("discover-interest-\(interest.category.rawValue)")
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
        }
        .discoverRailFade()
    }
}

// MARK: - Editor's pick

struct DiscoverEditorsPickCard: View {
    let item: DestinationItem
    let scale: CGFloat
    let onOpen: () -> Void
    let onCollect: () -> Void
    let onToggleSave: () -> Void

    @ScaledMetric(relativeTo: .title) private var nameSize = 26.0
    @ScaledMetric(relativeTo: .footnote) private var smallSize = 13.0
    @ScaledMetric(relativeTo: .caption) private var kickerSize = 11.0
    private var u: CGFloat { scale }
    private var inPassport: Bool { item.state.isInPassport }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 26, style: .continuous) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onOpen) { content.frame(maxWidth: .infinity, alignment: .leading).contentShape(shape) }.buttonStyle(.plain)
            actions.padding(.leading, 156 * u).padding(.bottom, 16).frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(minHeight: 196 * u)
        .background(HomeColor.card, in: shape).overlay(shape.strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .shadow(color: HomeColor.shadow1.opacity(0.10), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.destination.name), \(item.destination.countryName), \(item.destination.category.singularTitle). Editor’s pick."))
        .accessibilityValue(Text(item.state.discoverSpoken ?? String(localized: "Not collected")))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Collect")) { if !inPassport { onCollect() } }
        .accessibilityAction(named: item.state == .wishlisted ? Text("Remove from wishlist") : Text("Save to wishlist")) { if !inPassport { onToggleSave() } }
        .accessibilityIdentifier("discover-pick")
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 0) {
            DiscoverStamp(design: item.design, name: item.destination.name, showsTitle: true)
                .frame(width: 118 * u).rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.16), radius: 8, y: 5).padding(.leading, 23 * u).padding(.top, 26 * u)
            VStack(alignment: .leading, spacing: 0) {
                Text("EDITOR’S PICK").font(.system(size: kickerSize, weight: .bold)).tracking(0.12 * kickerSize).foregroundStyle(HomeColor.label)
                Text(item.destination.name).font(.system(size: nameSize, weight: .heavy)).tracking(-0.03 * nameSize).foregroundStyle(HomeColor.ink)
                    .lineLimit(2).minimumScaleFactor(0.8).padding(.top, 2)
                Text(item.destination.countryCategoryLine).font(.system(size: smallSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2).padding(.top, 4)
                Text(item.destination.summary).font(.system(size: smallSize, weight: .regular)).foregroundStyle(HomeColor.sub).lineLimit(2).padding(.top, 6)
                Color.clear.frame(height: 56)
            }
            .padding(.leading, 15 * u).padding(.trailing, 16).padding(.top, 20)
        }
    }

    @ViewBuilder private var actions: some View {
        if inPassport {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                Text("In your passport").font(.system(size: smallSize, weight: .semibold))
            }
            .foregroundStyle(HomeColor.label).frame(minHeight: 44)
        } else {
            HStack(spacing: 10 * u) {
                Button(action: onCollect) {
                    Text("Collect").font(.system(size: 15, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                        .frame(width: 104 * u, height: 40).background(HomeColor.cta, in: Capsule())
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("discover-pick-collect")
                Button(action: onToggleSave) {
                    let saved = item.state == .wishlisted
                    Image(systemName: saved ? "bookmark.fill" : "bookmark").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(saved ? HomeColor.label : HomeColor.ink).contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, options: .nonRepeating, value: saved)
                        .frame(width: 40, height: 40)
                        .background(saved ? PassportColor.accentTint : Color.clear, in: Circle())
                        .overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("discover-pick-save")
            }
        }
    }
}

// MARK: - Curated collections

struct DiscoverCollectionCard: View {
    let row: DiscoverCollectionRow
    let designs: [String: DestinationItem]
    let scale: CGFloat

    @ScaledMetric(relativeTo: .headline) private var titleSize = 17.0
    @ScaledMetric(relativeTo: .footnote) private var subSize = 12.5
    private var u: CGFloat { scale }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 24, style: .continuous) }
    private static let tilts: [Double] = [-4, 2, -2]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { slot in
                    let centre = (44 + 60 * CGFloat(slot)) * u
                    Group {
                        if slot < row.coverIDs.count, let item = designs[row.coverIDs[slot]] {
                            DiscoverStamp(design: item.design, name: item.destination.name).frame(width: 52 * u)
                                .rotationEffect(.degrees(Self.tilts[slot])).shadow(color: .black.opacity(0.18), radius: 4, y: 3)
                        } else { DiscoverDashedSlot(width: 52 * u, height: 70 * u) }
                    }
                    .offset(x: centre - 26 * u, y: 20 * u)
                }
            }
            .frame(height: 96 * u, alignment: .topLeading)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.collection.title).font(.system(size: titleSize, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(1)
                    Text("^[\(row.memberCount) place](inflect: true) · \(row.collectedCount) collected").font(.system(size: subSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.ink3)
            }
            .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 16)
        }
        .frame(width: 262 * u, alignment: .topLeading).frame(minHeight: 150 * u)
        .background(HomeColor.card, in: shape).overlay(shape.strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .shadow(color: HomeColor.shadow1.opacity(0.08), radius: 10, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(row.collection.title). ^[\(row.memberCount) place](inflect: true), \(row.collectedCount) collected"))
        .accessibilityAddTraits(.isButton)
    }
}

struct DiscoverCollectionRail: View {
    let rows: [DiscoverCollectionRow]
    let items: [String: DestinationItem]
    let scale: CGFloat
    let onOpen: (DiscoverCollectionRow) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(rows) { row in
                    Button { onOpen(row) } label: { DiscoverCollectionCard(row: row, designs: items, scale: scale) }
                        .buttonStyle(.plain).accessibilityIdentifier("discover-collection-\(row.collection.id)")
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 6)
        }
        .discoverRailFade()
    }
}

// MARK: - Continue exploring

struct DiscoverRecents: View {
    let items: [DestinationItem]
    let scale: CGFloat
    let onOpen: (DestinationItem) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var nameSize = 14.5
    @ScaledMetric(relativeTo: .caption) private var subSize = 12.0
    private static let tilts: [Double] = [-2, 1.5, -1]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button { onOpen(item) } label: {
                    VStack(spacing: 9) {
                        DiscoverStamp(design: item.design, name: item.destination.name, aspect: 0.75).frame(width: 104 * scale)
                            .rotationEffect(.degrees(Self.tilts[index % Self.tilts.count]))
                            .discoverStateBadge(item.state)
                        VStack(spacing: 1) {
                            Text(item.destination.name).font(.system(size: nameSize, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(2)
                            Text(item.destination.countryName).font(.system(size: subSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(item.destination.name), \(item.destination.countryName)." + (item.state.discoverSpoken.map { " \($0)." } ?? "")))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("discover-recent-\(item.id)")
            }
            // Keeps three cells' pitch when there are fewer than three places.
            ForEach(0..<max(0, 3 - items.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
        }
    }
}

// MARK: - Wishlist row, note

struct DiscoverWishlistRow: View {
    let items: [DestinationItem]
    let count: Int
    let onOpen: () -> Void

    @ScaledMetric(relativeTo: .headline) private var titleSize = 17.0
    @ScaledMetric(relativeTo: .footnote) private var subSize = 13.0
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 24, style: .continuous) }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 0) {
                stamps.frame(width: 90, height: 70).padding(.leading, 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your wishlist").font(.system(size: titleSize, weight: .semibold)).foregroundStyle(HomeColor.ink)
                    subline.font(.system(size: subSize, weight: .medium)).foregroundStyle(HomeColor.sub).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 10)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3).padding(.trailing, 20)
            }
            .frame(minHeight: 92).background(HomeColor.card, in: shape).overlay(shape.strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .shadow(color: HomeColor.shadow1.opacity(0.08), radius: 10, y: 5).contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 0 ? Text("Your wishlist. Save places you want to collect later.") : Text("Your wishlist, ^[\(count) place](inflect: true) saved for later"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("discover-wishlist-row")
    }

    private var subline: Text {
        count == 0 ? Text("Save places you want to collect later.") : Text("^[\(count) place](inflect: true) saved for later")
    }

    @ViewBuilder private var stamps: some View {
        ZStack {
            if items.isEmpty {
                DiscoverDashedSlot(width: 40, height: 52).rotationEffect(.degrees(-5)).offset(x: -18, y: 2)
                DiscoverDashedSlot(width: 40, height: 52).rotationEffect(.degrees(4)).offset(x: 18, y: -2)
            } else {
                DiscoverStamp(design: items[0].design, name: items[0].destination.name).frame(width: 40).rotationEffect(.degrees(-5)).offset(x: items.count > 1 ? -18 : 0, y: 2)
                if items.count > 1 {
                    DiscoverStamp(design: items[1].design, name: items[1].destination.name).frame(width: 40).rotationEffect(.degrees(4)).offset(x: 18, y: -2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct DiscoverEditorNote: View {
    @ScaledMetric(relativeTo: .footnote) private var size = 13.0

    var body: some View {
        Text("Places are picked by the StampQuest team from the catalog. Nothing here is ranked by popularity.")
            .font(.system(size: size, weight: .regular)).foregroundStyle(HomeColor.sub).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}
