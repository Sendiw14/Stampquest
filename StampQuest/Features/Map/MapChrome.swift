import SwiftUI

/// A round glass control of the Map: 44 pt hit area, glass over the map or poster, solid under Reduce Transparency.
struct MapRoundButton: View {
    let symbol: String
    var filled = false
    var size: CGFloat = 44
    var onPoster = false
    let label: LocalizedStringKey
    var value: LocalizedStringKey?
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.clear).frame(width: size, height: size).modifier(RoundGlass(onPoster: onPoster, filled: filled))
                Image(systemName: symbol).font(.system(size: size < 44 ? 19 : 20, weight: .medium))
                    .foregroundStyle(filled ? HomeColor.ctaText : (onPoster ? MapColor.onCover : HomeColor.ink))
            }
            .frame(width: max(44, size), height: max(44, size)).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityValue(value.map { Text($0) } ?? Text(""))
        .accessibilityIdentifier(identifier)
    }
}

private struct RoundGlass: ViewModifier {
    let onPoster: Bool
    let filled: Bool

    func body(content: Content) -> some View {
        if filled { content.background(HomeColor.cta, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)) }
        else if onPoster { content.posterGlass(Circle()) }
        else { content.cardGlass(Circle(), tint: 0.58, lined: true).shadow(color: .black.opacity(0.14), radius: 6, y: 2) }
    }
}

/// All, Collected, Verified, Saved: one row of chips with the real counts. The same layer drives the map and the list.
struct MapLayerChips: View {
    let layer: MapLayer
    let counts: MapCounts
    var glass = true
    let onSelect: (MapLayer) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) { row.padding(.trailing, 20) }
                    .mask(HStack(spacing: 0) { Color.black; LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 24) })
                    .onChange(of: layer, initial: true) { _, new in withAnimation { reader.scrollTo(new, anchor: .center) } }
            }
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            ForEach(MapLayer.allCases) { chip in
                MapChip(layer: chip, count: count(chip), selected: chip == layer, glass: glass) { onSelect(chip) }.id(chip)
            }
        }
    }

    private func count(_ chip: MapLayer) -> Int? {
        switch chip {
        case .all: nil
        case .collected: counts.collected
        case .verified: counts.verified
        case .saved: counts.saved
        }
    }
}

private struct MapChip: View {
    let layer: MapLayer
    let count: Int?
    let selected: Bool
    let glass: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .subheadline) private var size = 13.5

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if layer == .verified { VerifiedSeal(size: 14) }
                Text(layer.title).font(.system(size: size, weight: selected ? .bold : .semibold))
                if let count { Text("\(count)").font(.system(size: size, weight: .semibold)).monospacedDigit().opacity(0.8) }
            }
            .foregroundStyle(selected ? HomeColor.ctaText : HomeColor.ink)
            .padding(.horizontal, 11).frame(minHeight: 36)
            .background { fill }
            .overlay(Capsule().strokeBorder(selected ? Color.white.opacity(0.18) : (glass && !reduceTransparency ? Color.white.opacity(0.4) : PassportColor.cardLine), lineWidth: 1))
            .shadow(color: selected ? HomeColor.cta.opacity(0.4) : .clear, radius: 5, y: 2)
            .frame(minHeight: 44).contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(spoken))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("map-chip-\(layer.rawValue)")
    }

    @ViewBuilder
    private var fill: some View {
        if selected { Capsule().fill(HomeColor.cta) }
        else if glass { Capsule().fill(.clear).cardGlass(Capsule(), tint: 0.58, lined: false) }
        else { Capsule().fill(PassportColor.quiet) }
    }

    private var spoken: String {
        guard let count else { return layer.title }
        return "\(layer.title), \(count.placesPhrase)"
    }
}

/// The counts line under the title.
struct MapCountsLine: View {
    let counts: MapCounts
    @ScaledMetric(relativeTo: .subheadline) private var size = 15.0

    var body: some View {
        Text(counts.line).font(.system(size: size, weight: .medium)).foregroundStyle(MapColor.onCover.opacity(0.98))
            .accessibilityIdentifier("map-counts")
    }
}

// MARK: - Preview card

/// The glass ticket that rises over the bottom of the window while a place is selected.
struct MapPreviewCard: View {
    let place: MapPlace
    let state: StampState
    let onOpen: () -> Void
    let onCollect: () -> Void
    let onToggleSave: () -> Void
    let onOpenStamp: () -> Void
    @ScaledMetric(relativeTo: .title2) private var nameSize = 22.0
    @ScaledMetric(relativeTo: .footnote) private var subSize = 13.5
    @ScaledMetric(relativeTo: .caption) private var stateSize = 12.5
    @ScaledMetric(relativeTo: .subheadline) private var buttonSize = 14.5

    private var destination: Destination { place.destination }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 0) {
                    stamp.frame(width: 98).padding(.top, 18)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(destination.name).font(.system(size: nameSize, weight: .heavy)).tracking(-0.03 * nameSize)
                            .foregroundStyle(HomeColor.ink).lineLimit(1).minimumScaleFactor(0.8).padding(.trailing, 44)
                        Text(destination.countryCategoryLine).font(.system(size: subSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2)
                            .padding(.top, 1)
                        stateLine.padding(.top, 5)
                        Color.clear.frame(height: 38 + 12)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 16).padding(.trailing, 16)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold)).foregroundStyle(HomeColor.sub)
                        .padding(.top, 20).padding(.trailing, 31).accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("map-card-open")
            .accessibilityLabel(Text("\(destination.name), \(destination.countryName), \(destination.category.singularTitle)"))
            .accessibilityValue(Text(spokenState)).accessibilityHint(Text("Opens the place"))

            actions.padding(.leading, 98).padding(.trailing, 16).padding(.bottom, 8)
        }
        .frame(minHeight: 140)
        .cardGlass(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: 0.86)
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center), lineWidth: 1).allowsHitTesting(false))
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Collect stamp")) { if !state.isInPassport { onCollect() } }
        .accessibilityAction(named: Text(state == .wishlisted ? "Remove from wishlist" : "Save to wishlist")) { if !state.isInPassport { onToggleSave() } }
        .accessibilityAction(named: Text("Open details"), onOpen)
    }

    private var spokenState: String {
        switch state {
        case .notCollected: String(localized: "Not in your passport yet")
        case .wishlisted: String(localized: "On your wishlist")
        case .collected: String(localized: "In your passport")
        case .verified: String(localized: "Verified visit")
        }
    }

    private var stamp: some View {
        Group {
            if let design = place.design {
                PerforatedStampView(design: design, showsTitle: false, isDecorative: true, lifted: true, aspectRatio: 3.0 / 4.0).frame(width: 52)
            } else {
                MapStampPlaceholder().frame(width: 46, height: 62)
            }
        }
        .rotationEffect(.degrees(-2)).shadow(color: .black.opacity(0.2), radius: 5, y: 3)
    }

    @ViewBuilder
    private var stateLine: some View {
        switch state {
        case .notCollected:
            Text("Not in your passport yet").font(.system(size: stateSize, weight: .medium)).foregroundStyle(HomeColor.sub)
        case .wishlisted:
            HStack(spacing: 5) {
                Image(systemName: "bookmark.fill").font(.system(size: stateSize, weight: .bold))
                Text("On your wishlist").font(.system(size: stateSize, weight: .semibold))
            }.foregroundStyle(HomeColor.label)
        case .collected:
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: stateSize, weight: .heavy))
                Text("In your passport").font(.system(size: stateSize, weight: .semibold))
            }.foregroundStyle(HomeColor.label)
        case .verified:
            HStack(spacing: 5) {
                VerifiedSeal(size: 17)
                Text("Verified visit").font(.system(size: stateSize, weight: .semibold))
            }.foregroundStyle(HomeColor.ink)
        }
    }

    /// Collect or view, and the bookmark where it applies. At large type the buttons stack.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { primary; bookmark }
            VStack(alignment: .leading, spacing: 8) { primary; bookmark }
        }
    }

    @ViewBuilder
    private var primary: some View {
        if state.isInPassport {
            Button(action: onOpenStamp) {
                HStack(spacing: 5) {
                    Text(state == .verified ? "View in passport" : "View stamp").font(.system(size: buttonSize, weight: .bold))
                    Image(systemName: "chevron.right").font(.system(size: buttonSize - 2, weight: .bold))
                }
                .foregroundStyle(HomeColor.ink).frame(maxWidth: 178, minHeight: 38).padding(.horizontal, 12)
                .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                .frame(minHeight: 44).contentShape(Capsule())
            }
            .buttonStyle(.plain).padding(.vertical, -3).accessibilityIdentifier("map-card-view-stamp")
        } else {
            Button(action: onCollect) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: buttonSize, weight: .bold))
                    Text("Collect stamp").font(.system(size: buttonSize, weight: .bold))
                }
                .foregroundStyle(HomeColor.ctaText).frame(maxWidth: 178, minHeight: 38).padding(.horizontal, 12)
                .background(HomeColor.cta, in: Capsule()).frame(minHeight: 44).contentShape(Capsule())
            }
            .buttonStyle(.plain).padding(.vertical, -3).accessibilityIdentifier("map-card-collect")
        }
    }

    @ViewBuilder
    private var bookmark: some View {
        if !state.isInPassport {
            let saved = state == .wishlisted
            Button(action: onToggleSave) {
                Image(systemName: saved ? "bookmark.fill" : "bookmark").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(saved ? HomeColor.label : HomeColor.ink).frame(width: 38, height: 38)
                    .background(saved ? PassportColor.accentTint : PassportColor.quiet, in: Circle())
                    .overlay(Circle().strokeBorder(saved ? PassportColor.accentBorder : PassportColor.cardLine, lineWidth: 1))
                    .frame(width: 44, height: 44).contentShape(Circle())
            }
            .buttonStyle(.plain).padding(.vertical, -3)
            .accessibilityLabel(Text(saved ? "Remove from wishlist" : "Save to wishlist"))
            .accessibilityIdentifier("map-card-save")
        }
    }
}

// MARK: - Banner, empty layer, unavailable

/// Shown when Locate is tapped and permission is off. Never blocks the map or the list.
struct MapLocationOffBanner: View {
    let onSettings: () -> Void
    @ScaledMetric(relativeTo: .body) private var titleSize = 16.5
    @ScaledMetric(relativeTo: .footnote) private var bodySize = 13.5

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "location.slash").font(.system(size: 18, weight: .semibold)).foregroundStyle(HomeColor.label)
                .frame(width: 40, height: 40).background(PassportColor.accentTint, in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Location is off").font(.system(size: titleSize, weight: .semibold)).foregroundStyle(HomeColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    Button(action: onSettings) {
                        Text("Settings").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(HomeColor.label)
                            .padding(.horizontal, 12).frame(minHeight: 28)
                            .background(PassportColor.accentTint, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.accentBorder, lineWidth: 1))
                            .frame(minWidth: 44, minHeight: 44).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).padding(.vertical, -8).padding(.top, -4).accessibilityIdentifier("map-banner-settings")
                }
                Text("Turn it on in Settings to use Locate. Everything else still works.").font(.system(size: bodySize, weight: .regular))
                    .foregroundStyle(HomeColor.sub).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass(RoundedRectangle(cornerRadius: 28, style: .continuous), tint: 0.86)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
    }
}

/// The chosen layer has no places: the map shows no markers and this card offers the way back.
struct MapEmptyLayerCard: View {
    let layer: MapLayer
    let onShowAll: () -> Void

    private var title: LocalizedStringKey {
        switch layer {
        case .verified: "No verified visits yet"
        case .collected: "Nothing collected yet"
        case .saved: "Nothing saved yet"
        case .all: "No places to show"
        }
    }

    private var message: LocalizedStringKey {
        switch layer {
        case .verified: "Verify a visit from a place’s page and it appears here."
        case .collected: "Collect a place and it appears here."
        case .saved: "Tap the bookmark on a place to save it for later."
        case .all: "There are no places on the map right now."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin").font(.system(size: 20, weight: .semibold)).foregroundStyle(HomeColor.label)
                .frame(width: 48, height: 48)
                .overlay(Circle().strokeBorder(HomeColor.label.opacity(0.7), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3])))
                .accessibilityHidden(true)
            Text(title).font(.system(size: 20, weight: .heavy)).foregroundStyle(HomeColor.ink).multilineTextAlignment(.center)
                .padding(.top, 12).accessibilityAddTraits(.isHeader)
            Text(message).font(.system(size: 14, weight: .regular)).foregroundStyle(HomeColor.sub).multilineTextAlignment(.center)
                .frame(maxWidth: 302).padding(.top, 6)
            if layer != .all {
                Button(action: onShowAll) {
                    Text("Show all places").font(.system(size: 14.5, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                        .frame(minWidth: 162, minHeight: 40).padding(.horizontal, 12).background(HomeColor.cta, in: Capsule())
                        .frame(minHeight: 44).contentShape(Capsule())
                }
                .buttonStyle(.plain).padding(.top, 10).accessibilityIdentifier("map-empty-show-all")
            }
        }
        .padding(.vertical, 20).padding(.horizontal, 16).frame(maxWidth: .infinity)
        .cardGlass(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: 0.86)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
    }
}

/// The toast, drawn over the map: 12 pt above the card, or above the window's bottom edge when no card shows.
struct MapToastOverlay: ViewModifier {
    let center: ToastCenter
    let bottomInset: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = center.current {
                DiscoverToastView(toast: toast) { center.undo() }
                    .padding(.horizontal, -8).padding(.bottom, bottomInset)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: toast.message) }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85), value: center.current?.id)
    }
}

struct MapCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
