import SwiftUI

/// The bookmark circle with its count badge. On the poster it is glass with a cream badge; in the glass bar it is a quiet
/// circle with an accent badge. Both open the Wishlist.
struct DiscoverWishlistButton: View {
    enum Style { case poster, bar }

    let count: Int
    let style: Style
    var scale: CGFloat = 1
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var diameter: CGFloat { (style == .poster ? 40 : 36) * scale }

    var body: some View {
        Button(action: action) {
            Image(systemName: "bookmark").font(.system(size: (style == .poster ? 16 : 15) * scale, weight: .semibold))
                .foregroundStyle(style == .poster ? HomeColor.cream : HomeColor.ink)
                .frame(width: diameter, height: diameter)
                .background { background }
                .overlay(alignment: .topTrailing) { if count > 0 { badge.offset(x: 5 * scale, y: -5 * scale) } }
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count == 0 ? Text("Wishlist") : Text("Wishlist, ^[\(count) place](inflect: true)"))
        .onChange(of: count) { old, new in
            guard !reduceMotion, new != old else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pulse = true }
            Task { try? await Task.sleep(for: .milliseconds(160)); withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pulse = false } }
        }
    }

    @ViewBuilder private var background: some View {
        if style == .poster { Color.clear.posterGlass(Circle()) }
        else { Circle().fill(PassportColor.quiet) }
    }

    private var badge: some View {
        Text(count > 99 ? "99+" : "\(count)").font(.system(size: 11, weight: .heavy)).monospacedDigit().minimumScaleFactor(0.7)
            .foregroundStyle(style == .poster ? Color(hex: 0x8A4526) : HomeColor.ctaText)
            .frame(minWidth: 18, minHeight: 18).padding(.horizontal, count > 99 ? 3 : 0)
            .background(style == .poster ? HomeColor.cream : HomeColor.cta, in: Capsule())
            .scaleEffect(pulse ? 1.35 : 1)
            .accessibilityHidden(true)
    }
}

/// The large glass search ticket: the field opens Search, the round button opens Filters.
struct DiscoverTicketView: View {
    let scale: CGFloat
    let onSearch: () -> Void
    let onFilters: () -> Void

    @ScaledMetric(relativeTo: .body) private var textSize = 16.0
    private var u: CGFloat { scale }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSearch) {
                HStack(spacing: 8 * u) {
                    Image(systemName: "magnifyingglass").font(.system(size: 19 * u, weight: .medium)).foregroundStyle(HomeColor.sub).frame(width: 24 * u)
                    Text("Search places or landmarks").font(.system(size: textSize * u, weight: .medium)).foregroundStyle(HomeColor.sub)
                        .lineLimit(2).multilineTextAlignment(.leading).minimumScaleFactor(0.8)
                }
                .padding(.leading, 22 * u).frame(maxWidth: .infinity, minHeight: 64 * u, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Search places or landmarks")).accessibilityHint(Text("Opens search"))
            .accessibilityIdentifier("discover-search-field")

            Button(action: onFilters) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 17 * u, weight: .semibold)).foregroundStyle(HomeColor.ctaText)
                    .frame(width: 44 * u, height: 44 * u).background(HomeColor.cta, in: Circle())
                    .shadow(color: HomeColor.cta.opacity(0.40), radius: 8, y: 4)
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.trailing, 10 * u)
            .accessibilityLabel(Text("Filters")).accessibilityIdentifier("discover-filter-button")
        }
        .frame(minHeight: 64 * u)
        .cardGlass(RoundedRectangle(cornerRadius: 32 * u, style: .continuous), tint: 0.86)
        .shadow(color: HomeColor.shadow1.opacity(0.16), radius: 14, y: 8)
    }
}

/// The poster: title, the real "places to collect" line, the wishlist button and a fan of two catalog stamps. Laid out on
/// the 402 pt reference canvas scaled by `scale`; `topExtra` pushes everything below a taller status area.
struct DiscoverHeroView: View {
    static let posterHeight: CGFloat = 330

    let scale: CGFloat
    let topExtra: CGFloat
    let placesToCollect: Int
    let wishlistCount: Int
    let fan: [DestinationItem]
    let entered: Bool
    let onWishlist: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38.0
    @ScaledMetric(relativeTo: .subheadline) private var subSize = 15.0

    private var u: CGFloat { scale }
    private var rise: CGFloat { reduceMotion ? 0 : 12 }

    var body: some View {
        ZStack(alignment: .top) {
            PosterBackground()
            ZStack(alignment: .topLeading) {
                fanView
                column
                DiscoverWishlistButton(count: wishlistCount, style: .poster, scale: u, action: onWishlist)
                    .offset(x: 336 * u, y: 60 * u + topExtra)
                    .opacity(entered ? 1 : 0).offset(y: entered || reduceMotion ? 0 : -8)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: entered)
                    .accessibilityIdentifier("discover-wishlist-button")
            }
            .frame(width: 402 * u, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: Self.posterHeight * u + topExtra, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Discover").font(.system(size: titleSize * u, weight: .heavy)).tracking(-0.04 * titleSize * u)
                .foregroundStyle(HomeColor.onPoster).lineLimit(1).minimumScaleFactor(0.6).accessibilityAddTraits(.isHeader)
            subline.font(.system(size: subSize * u, weight: .medium)).foregroundStyle(HomeColor.onPoster.opacity(0.98))
                .fixedSize(horizontal: false, vertical: true).padding(.top, 2 * u).accessibilityIdentifier("discover-subline")
        }
        .frame(width: 170 * u, alignment: .leading)
        .padding(.leading, 24 * u).padding(.top, 98 * u + topExtra)
        .opacity(entered ? 1 : 0).offset(y: entered ? 0 : rise)
        .animation(.easeOut(duration: 0.5), value: entered)
    }

    private var subline: Text {
        placesToCollect == 0 ? Text("You have every place so far.") : Text("^[\(placesToCollect) place](inflect: true) to collect")
    }

    /// Decorative: not tappable and hidden from VoiceOver. Only stamps that exist in the catalog.
    private var fanView: some View {
        ZStack(alignment: .topLeading) {
            if let first = fan.first { stamp(first, width: 82, centre: CGPoint(x: 246, y: 200), tilt: -11, from: (44, 34, -23)) }
            if fan.count > 1 { stamp(fan[1], width: 102, centre: CGPoint(x: 318, y: 188), tilt: 7, from: (-34, 44, 19)) }
        }
        .accessibilityHidden(true).allowsHitTesting(false)
    }

    private func stamp(_ item: DestinationItem, width: CGFloat, centre: CGPoint, tilt: Double, from: (CGFloat, CGFloat, Double)) -> some View {
        let landed = entered || reduceMotion
        return DiscoverStamp(design: item.design, name: item.destination.name, showsTitle: true)
            .frame(width: width * u)
            .rotationEffect(.degrees(landed ? tilt : from.2))
            .shadow(color: .black.opacity(0.30), radius: 3, y: 2)
            .shadow(color: Color(hex: 0x3C1608).opacity(0.40), radius: 16, y: 14)
            .offset(x: (centre.x - width / 2) * u + (landed ? 0 : from.0),
                    y: (centre.y - width / StampMetrics.aspectRatio / 2) * u + topExtra + (landed ? 0 : from.1))
            .opacity(entered ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.7, dampingFraction: 0.62).delay(0.08), value: entered)
    }
}
