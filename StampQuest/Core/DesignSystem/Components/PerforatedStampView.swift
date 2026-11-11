import SwiftUI

/// How strongly a stamp is rendered.
enum StampPresentation {
    /// Full colour: collected, previewed, or revealed.
    case full
    /// Desaturated "ghost" for stamps the user does not have yet.
    case muted
}

extension StampDesign {
    var borderTint: RGB { RGB(hexString: artwork.palette.tint) ?? RGB(r: 0.72, g: 0.44, b: 0.29) }
}

/// A complete postage stamp: perforated paper border, illustration, keyline and
/// engraved title. The single stamp renderer used across the whole app.
struct PerforatedStampView: View {
    let design: StampDesign
    var presentation: StampPresentation = .full
    /// Shows the engraved destination name on the artwork.
    var showsTitle: Bool = true
    /// When true the stamp is decoration and is hidden from VoiceOver.
    var isDecorative: Bool = false
    /// Adds the soft drop shadow that lifts a stamp off the page.
    var lifted: Bool = true
    /// Width over height. Most of the app uses the shared 4:5; the Passport grid draws every stamp at 3:4.
    var aspectRatio: CGFloat = StampMetrics.aspectRatio

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let inset = w * StampMetrics.insetRatio
            let paper = presentation == .full ? design.borderTint.color : SQColor.stone

            ZStack(alignment: .topLeading) {
                PerforatedStampShape()
                    .fill(paper)
                    .shadow(color: .black.opacity(lifted ? 0.16 : 0), radius: w * 0.014, x: 0, y: w * 0.008)

                // Paper highlight so the border reads as paper, not flat colour.
                PerforatedStampShape()
                    .fill(LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.06)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))

                artwork(width: w - inset * 2, height: h - inset * 2, stampWidth: w)
                    .frame(width: w - inset * 2, height: h - inset * 2)
                    .clipped()
                    .overlay(Rectangle().strokeBorder(SQColor.stampPaper.opacity(0.92), lineWidth: max(0.6, w * 0.01)))
                    .saturation(presentation == .full ? 1 : 0.05)
                    .contrast(presentation == .full ? 1 : 0.9)
                    .opacity(presentation == .full ? 1 : 0.82)
                    .offset(x: inset, y: inset)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(design.accessibilityDescription)
        .accessibilityAddTraits(.isImage)
        // Last, so a decorative stamp is really hidden (hiding first was undone by the element modifier above).
        .accessibilityHidden(isDecorative)
    }

    private func titleText(_ w: CGFloat) -> some View {
        Text(design.title.uppercased())
            .font(.system(size: w * 0.07, weight: .bold, design: .serif))
            .tracking(w * 0.004)
            .lineLimit(1)
    }

    private func editionText(_ w: CGFloat) -> some View {
        Text(design.edition.uppercased())
            .font(.system(size: w * 0.034, weight: .medium, design: .monospaced))
            .opacity(0.85)
    }

    private func artwork(width: CGFloat, height: CGFloat, stampWidth w: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            StampArtworkView(spec: design.artwork, seedKey: design.id)
            if showsTitle && w >= 70 {
                LinearGradient(colors: [.clear, .black.opacity(0.38)], startPoint: .center, endPoint: .bottom)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .lastTextBaseline) {
                        titleText(w)
                        Spacer(minLength: 0)
                        if w >= 120 { editionText(w) }
                    }
                    HStack { titleText(w).minimumScaleFactor(0.5); Spacer(minLength: 0) }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 1.2, y: 0.5)
                .padding(.horizontal, w * 0.04)
                .padding(.bottom, w * 0.034)
                // The engraved name repeats the stamp's own label; it is art, not a separate element.
                .accessibilityHidden(true)
            }
        }
    }
}
