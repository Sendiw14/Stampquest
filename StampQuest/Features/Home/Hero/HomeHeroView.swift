import SwiftUI

/// The poster: header, "Your passport has", the numeral window, the word chip, the stamp stack. Laid out on the
/// 402 pt reference canvas (y measured from the safe-area top) and scaled uniformly by the caller.
struct HomeHeroView: View {
    static let canvas = CGSize(width: 402, height: 541)
    let home: HomeSnapshot
    let featured: DestinationItem?
    let side: DestinationItem?
    let name: String
    let cover: PassportStyle
    let drifts: Bool
    let onSettings: () -> Void
    let onSearch: () -> Void
    let onSwap: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var textX: CGFloat { home.isFirstRun ? 190 : 232 }
    private var textWidth: CGFloat { 402 - textX - 20 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NumeralWindowView(text: home.isFirstRun ? "1" : HomeCopy.numeralText(home.stampCount), design: featured?.design, drifts: drifts)
                .offset(x: 10, y: 69)
            if let side { sideStamp(side) }
            if let featured { heroStamp(featured) }
            header
            Color.clear.frame(width: 1, height: 1).accessibilityElement().accessibilityLabel(Text(spokenSummary))
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("home-hero-summary")
            Text(home.isFirstRun ? "Start your passport with" : "Your passport has")
                .font(.system(size: 18, weight: .bold)).tracking(-0.012 * 18)
                .foregroundStyle(HomeColor.onPoster.opacity(0.97))
                .offset(x: 24, y: 59).accessibilityHidden(true)
            HomeStampWord(text: home.stampCount == 1 || home.isFirstRun ? "stamp" : "stamps").offset(x: textX, y: 91).accessibilityHidden(true)
            Text(subText)
                .font(.system(size: 15, weight: .medium)).foregroundStyle(HomeColor.onPoster.opacity(0.98))
                .frame(width: textWidth, alignment: .leading).offset(x: textX, y: 149).accessibilityHidden(true)
            if let chip { chipView(chip).offset(x: textX, y: 175) }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
        .environment(\.dynamicTypeSize, .large)
    }

    // MARK: Pieces

    private var spokenSummary: LocalizedStringKey {
        home.isFirstRun ? "Start your passport with a free stamp"
            : "Your passport has ^[\(home.stampCount) stamp](inflect: true) from ^[\(home.countryCount) country](inflect: true)"
    }

    private var subText: LocalizedStringKey {
        home.isFirstRun ? "Free. No account." : "from ^[\(home.countryCount) country](inflect: true)"
    }

    private var chip: LocalizedStringKey? {
        switch home.chip {
        case .places(let count): "Over \(count) places"
        case .verified(let count): "^[\(count) verified visit](inflect: true)"
        case .since(let date): "Collecting since \(date.formatted(.dateTime.month(.abbreviated).year()))"
        case nil: nil
        }
    }

    private func chipView(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.system(size: 12.5, weight: .bold)).foregroundStyle(HomeColor.onPoster)
            .lineLimit(1).fixedSize().padding(.horizontal, 12).frame(height: 28)
            .background(glass(Capsule()))
            .accessibilityHidden(true)
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onSettings) { PassportBookView(style: cover, width: 32).frame(width: 32, height: 44).clipped() }
                .frame(minWidth: 44, minHeight: 48).contentShape(Rectangle())
                .offset(x: 14, y: -1).accessibilityLabel(Text("Settings")).accessibilityIdentifier("settings-button")
            VStack(alignment: .leading, spacing: 0) {
                Text(greeting).font(.system(size: name.isEmpty ? 15 : 12.5, weight: name.isEmpty ? .bold : .medium))
                    .foregroundStyle(HomeColor.onPoster.opacity(0.95))
                if !name.isEmpty { Text(name).font(.system(size: 21, weight: .heavy)).tracking(-0.03 * 21).foregroundStyle(HomeColor.onPoster).lineLimit(1) }
            }
            .frame(width: 215, alignment: .leading).offset(x: 63, y: 0)
            Button(action: onSearch) { Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.onPoster)
                .frame(width: 40, height: 40).background(glass(Circle())) }
                .frame(width: 44, height: 44).contentShape(Rectangle()).offset(x: 288, y: 1)
                .accessibilityLabel(Text("Search")).accessibilityIdentifier("home-search")
        }
    }

    private var greeting: String {
        switch home.greeting {
        case .morning: String(localized: "Good morning,")
        case .afternoon: String(localized: "Good afternoon,")
        case .evening: String(localized: "Good evening,")
        case .hello: String(localized: "Hello,")
        case .welcome: String(localized: "Welcome,")
        }
    }

    private func glass<S: InsettableShape>(_ shape: S) -> some View {
        let dark = scheme == .dark
        return ZStack {
            if reduceTransparency { shape.fill(dark ? Color(hex: 0x3A3733) : Color(hex: 0x6A3420)) }
            else {
                shape.fill(.ultraThinMaterial)
                shape.fill(HomeColor.glassFill.opacity(dark ? 0.10 : 0.30))
            }
            shape.strokeBorder(.white.opacity(dark ? 0.22 : 0.34), lineWidth: 1)
        }
    }

    private func stamp(_ item: DestinationItem, width: CGFloat) -> some View {
        PerforatedStampView(design: item.design, showsTitle: width > 100, isDecorative: true, lifted: false)
            .frame(width: width)
            .shadow(color: Color(hex: 0x220A02).opacity(0.55), radius: 0.5, y: 2)
            .shadow(color: Color(hex: 0x220A02).opacity(0.50), radius: 7, y: 16)
            .shadow(color: Color(hex: 0x220A02).opacity(0.34), radius: 15, y: 36)
    }

    private func heroStamp(_ item: DestinationItem) -> some View {
        stamp(item, width: 168).rotationEffect(.degrees(8)).position(x: 288, y: 379)
            .id(item.id).transition(.opacity)
    }

    private func sideStamp(_ item: DestinationItem) -> some View {
        Button(action: onSwap) { stamp(item, width: 84).rotationEffect(.degrees(-12)) }
            .buttonStyle(.plain).frame(minWidth: 84, minHeight: 105)
            .position(x: 66, y: 427)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Switch featured stamp to \(item.destination.name)"))
            .accessibilityIdentifier("home-side-stamp")
            .id(item.id).transition(.opacity)
    }
}
