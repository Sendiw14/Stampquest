import SwiftUI

/// The poster: title, subline, share, "Open pages" and the closed cover tucked behind the ticket. Laid out on the
/// 402 pt reference canvas scaled by `scale`; `topExtra` pushes everything below a taller status area.
struct PassportHeroView: View {
    static let posterHeight: CGFloat = 330

    let scale: CGFloat
    let topExtra: CGFloat
    let metrics: PassportMetrics
    let isEmpty: Bool
    let ownerName: String
    let coverStyle: CoverStyle
    /// False until the entrance runs; flipped once per session.
    let entered: Bool
    let onShare: () -> Void
    let onOpenPages: () -> Void
    let onCover: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38.0
    @ScaledMetric(relativeTo: .subheadline) private var subSize = 15.0
    @ScaledMetric(relativeTo: .subheadline) private var chipSize = 14.0

    private var u: CGFloat { scale }
    private var rise: CGFloat { reduceMotion ? 0 : 12 }

    var body: some View {
        ZStack(alignment: .top) {
            PosterBackground()
            ZStack(alignment: .topLeading) {
                cover
                if !isEmpty { shareButton }
                column
            }
            .frame(width: 402 * u, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: Self.posterHeight * u + topExtra, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Passport").font(.system(size: titleSize * u, weight: .heavy)).tracking(-0.04 * titleSize * u)
                .foregroundStyle(HomeColor.onPoster).lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            subline.font(.system(size: subSize * u, weight: .medium)).foregroundStyle(HomeColor.onPoster.opacity(0.98))
                .fixedSize(horizontal: false, vertical: true).padding(.top, 2 * u).accessibilityIdentifier("passport-subline")
            if !isEmpty { openPagesChip.padding(.top, 22 * u) }
        }
        .frame(width: 214 * u, alignment: .leading)
        .padding(.leading, 24 * u).padding(.top, 98 * u + topExtra).padding(.bottom, 52 * u)
        .opacity(entered ? 1 : 0).offset(y: entered ? 0 : rise)
        .animation(.easeOut(duration: 0.5), value: entered)
    }

    private var subline: Text {
        isEmpty ? Text("Nothing collected yet")
            : Text("^[\(metrics.collected) stamp](inflect: true) from ^[\(metrics.countries) country](inflect: true)")
    }

    private var openPagesChip: some View {
        Button(action: onOpenPages) {
            HStack(spacing: 6) {
                Text("Open pages").font(.system(size: chipSize * u, weight: .semibold))
                Image(systemName: "chevron.right").font(.system(size: 11 * u, weight: .bold))
            }
            .foregroundStyle(HomeColor.onPoster).padding(.horizontal, 16 * u).frame(minHeight: 36 * u)
            .posterGlass(Capsule())
        }
        .buttonStyle(.plain).frame(minHeight: 44).contentShape(Rectangle())
        .opacity(entered ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.25), value: entered)
        .accessibilityIdentifier("passport-open-pages")
    }

    private var shareButton: some View {
        Button(action: onShare) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 16 * u, weight: .semibold)).foregroundStyle(HomeColor.cream)
                .frame(width: 40 * u, height: 40 * u).posterGlass(Circle())
        }
        .buttonStyle(.plain).frame(width: 44, height: 44).contentShape(Rectangle())
        .offset(x: 336 * u, y: 60 * u + topExtra)
        .opacity(entered ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.25), value: entered)
        .accessibilityLabel(Text("Share passport")).accessibilityIdentifier("passport-share")
    }

    /// 118 pt wide, tilted 6 degrees, top-left at (256, 104). It drops in from below and settles with a little overshoot.
    private var cover: some View {
        Button(action: onCover) {
            PassportCover(style: coverStyle, holderName: ownerName, width: 118 * u)
                .rotationEffect(.degrees(entered || reduceMotion ? 6 : 16))
                .shadow(color: .black.opacity(0.30), radius: 3, y: 2)
                .shadow(color: Color(hex: 0x3C1608).opacity(0.45), radius: 18, y: 16)
        }
        .buttonStyle(.plain)
        .offset(x: 256 * u, y: 104 * u + topExtra + (entered || reduceMotion ? 0 : 46))
        .opacity(entered ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.7, dampingFraction: 0.62), value: entered)
        .accessibilityLabel(Text("Passport cover")).accessibilityHint(Text(isEmpty ? "" : "Opens your stamps as pages"))
        .accessibilityIdentifier("passport-cover")
        .disabled(isEmpty)
    }
}
