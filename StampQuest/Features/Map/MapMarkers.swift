import SwiftUI

/// What a marker looks like. Available, saved and collected are three different shapes, never colour alone; gold belongs
/// to the verified seal only.
struct MapMarkerContent: Equatable {
    enum Kind: Equatable { case available, saved, stamp, checkDot }

    var name: String
    var state: StampState
    var design: StampDesign?
    var selected = false
    var showsLabel = false

    var kind: Kind {
        switch state {
        case .notCollected: .available
        case .wishlisted: .saved
        case .collected, .verified: design == nil ? .checkDot : .stamp
        }
    }

    /// The visible size of the marker, hit area not included.
    var coreSize: CGSize {
        switch kind {
        case .available: selected ? CGSize(width: 50, height: 50) : CGSize(width: 17, height: 17)
        case .saved: selected ? CGSize(width: 50, height: 50) : CGSize(width: 30, height: 30)
        case .checkDot: selected ? CGSize(width: 50, height: 50) : CGSize(width: 17, height: 17)
        case .stamp: selected ? CGSize(width: 54, height: 67) : CGSize(width: 33, height: 44)
        }
    }

    /// The tappable size of the annotation: never under 44 pt each way.
    var hitSize: CGSize { CGSize(width: max(44, coreSize.width), height: max(44, coreSize.height)) }
}

/// The marker itself, without its label: the same views the Marker guide shows, so they cannot drift.
struct MapMarkerArt: View {
    let content: MapMarkerContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch content.kind {
            case .available: available
            case .saved: saved
            case .checkDot: checkDot
            case .stamp: stamp
            }
        }
        .frame(width: content.coreSize.width, height: content.coreSize.height)
        .animation(reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.68), value: content.selected)
        .animation(.easeInOut(duration: 0.16), value: content.state)
    }

    private var halo: some View {
        Circle().fill(MapColor.halo).overlay(Circle().strokeBorder(HomeColor.cta, lineWidth: 1.6)).frame(width: 50, height: 50)
    }

    private var available: some View {
        let d: CGFloat = content.selected ? 24 : 17
        return ZStack {
            if content.selected { halo }
            Circle().fill(HomeColor.card)
            Circle().strokeBorder(HomeColor.label, lineWidth: content.selected ? 2.8 : 2.4)
            Circle().fill(HomeColor.label).frame(width: d * 0.3, height: d * 0.3)
        }
        .frame(width: d, height: d)
        .frame(width: content.coreSize.width, height: content.coreSize.height)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private var saved: some View {
        let d: CGFloat = content.selected ? 36 : 30
        return ZStack {
            if content.selected { halo }
            Circle().fill(HomeColor.card).overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1.4)).frame(width: d, height: d)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1.5)
            Image(systemName: "bookmark.fill").font(.system(size: content.selected ? 20 : 17, weight: .bold)).foregroundStyle(HomeColor.label)
        }
    }

    /// A collected place whose stamp art is missing: the ring dot with the accent check.
    private var checkDot: some View {
        let d: CGFloat = 17
        return ZStack {
            if content.selected { halo }
            Circle().fill(HomeColor.cta).overlay(Circle().strokeBorder(HomeColor.card, lineWidth: 1.5))
                .overlay(Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(HomeColor.ctaText))
                .frame(width: d, height: d).shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
    }

    private var stamp: some View {
        let w: CGFloat = content.selected ? 40 : 33
        let h = w * 4 / 3
        return ZStack {
            if content.selected {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(MapColor.halo)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(HomeColor.cta, lineWidth: 1.6))
                    .frame(width: w + 14, height: h + 14)
            }
            DiscoverStamp(design: content.design, name: content.name, aspect: 3.0 / 4.0, lifted: false)
                .frame(width: w, height: h)
                .rotationEffect(.degrees(content.selected ? 0 : -2))
                .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                .shadow(color: .black.opacity(0.24), radius: 5, y: 3)
                .overlay(alignment: .bottomTrailing) { badge }
        }
    }

    @ViewBuilder
    private var badge: some View {
        // The badge's centre sits 4 pt inside the stamp's right and bottom edges.
        if content.state == .verified {
            VerifiedSeal(size: 26).offset(x: 26 / 2 - 4, y: 26 / 2 - 4)
        } else {
            Image(systemName: "checkmark").font(.system(size: 9.5, weight: .heavy)).foregroundStyle(HomeColor.ctaText)
                .frame(width: 17, height: 17).background(HomeColor.cta, in: Circle())
                .overlay(Circle().strokeBorder(HomeColor.card, lineWidth: 1.5))
                .offset(x: 17 / 2 - 4, y: 17 / 2 - 4)
        }
    }
}

/// A marker with its name under it, as drawn on the map. The name has a map-coloured halo so it reads on any map.
struct MapMarkerView: View {
    let content: MapMarkerContent
    @ScaledMetric(relativeTo: .caption) private var labelSize = 11.5

    var body: some View {
        MapMarkerArt(content: content)
            .overlay(alignment: .top) {
                if content.showsLabel {
                    Text(content.name).font(.system(size: labelSize, weight: .semibold)).foregroundStyle(HomeColor.ink)
                        .multilineTextAlignment(.center).lineLimit(2).frame(width: 112)
                        .shadow(color: MapColor.labelHalo, radius: 1).shadow(color: MapColor.labelHalo, radius: 1)
                        .shadow(color: MapColor.labelHalo, radius: 2).shadow(color: MapColor.labelHalo, radius: 2)
                        .offset(y: content.coreSize.height + 4).transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.16), value: content.showsLabel)
            .frame(width: Self.canvas.width, height: Self.canvas.height)
    }

    /// The hosting canvas: the marker is centred, the label hangs below it.
    static let canvas = CGSize(width: 140, height: 150)
}

/// A group of places that would overlap. Count centred; a check when one of them is already in the passport; never gold.
struct MapClusterView: View {
    let count: Int
    let hasCollected: Bool

    var body: some View {
        let d = MapClusterStyle.diameter(count: count)
        ZStack {
            Circle().fill(MapColor.clusterHalo).frame(width: d + 8 + 5, height: d + 8 + 5)
            Circle().fill(MapColor.clusterFill).overlay(Circle().strokeBorder(MapColor.clusterRing, lineWidth: 2.5)).frame(width: d, height: d)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1.5)
            Text("\(count)").font(.system(size: MapClusterStyle.countFontSize(count: count), weight: .heavy)).monospacedDigit()
                .foregroundStyle(MapColor.clusterText)
            if hasCollected {
                // The badge's centre sits 3 pt inside the circle's top and right edges.
                Image(systemName: "checkmark").font(.system(size: 10.5, weight: .heavy)).foregroundStyle(HomeColor.ctaText)
                    .frame(width: 19, height: 19).background(HomeColor.cta, in: Circle())
                    .overlay(Circle().strokeBorder(HomeColor.card, lineWidth: 1.5))
                    .offset(x: d / 2 - 3, y: -(d / 2 - 3))
            }
        }
        .frame(width: 70, height: 70)
    }
}

/// The user's own position while Locate is on: a blue dot with a white ring, no accuracy circle and no trail.
struct MapUserDot: View {
    var body: some View {
        Circle().fill(MapColor.you).frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .padding(3).background(Circle().fill(MapColor.you.opacity(0.18)).frame(width: 40, height: 40))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .frame(width: 44, height: 44)
    }
}

/// The dashed slot for a stamp whose art is missing: a dashed outline and a pin, never a blank hole.
struct MapStampPlaceholder: View {
    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(HomeColor.label.opacity(0.7), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
                .background(PassportColor.accentTint, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(Image(systemName: "mappin").font(.system(size: max(10, proxy.size.width * 0.34), weight: .semibold)).foregroundStyle(HomeColor.label))
        }
        .accessibilityHidden(true)
    }
}
