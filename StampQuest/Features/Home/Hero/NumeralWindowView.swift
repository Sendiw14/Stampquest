import SwiftUI

/// Today's stamp artwork seen through the digits of the count: an edge stroke, the art clipped to the glyphs, a shadow.
/// The art drifts a couple of points while `drifts` is true; the caller pauses it for Reduce Motion, Low Power Mode,
/// an off-screen hero and the background.
struct NumeralWindowView: View {
    static let box = CGSize(width: 236, height: 320)
    let text: String
    let design: StampDesign?
    let drifts: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let size = HomeCopy.numeralSize(unitWidth: GlyphPath.unitWidth(for: text))
        let glyphs = GlyphPath.path(for: text, size: size).offsetBy(dx: 12, dy: Self.box.height / 2)
        ZStack(alignment: .topLeading) {
            glyphs.stroke(HomeColor.numeralEdge, style: StrokeStyle(lineWidth: 13, lineJoin: .round))
            if let design {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !drifts)) { context in
                    let t = drifts ? context.date.timeIntervalSinceReferenceDate : 0
                    art(design, dx: 2 * sin(2 * .pi * t / 9), dy: sin(2 * .pi * t / 11.4))
                }
                .mask { glyphs.fill(.black) }
            } else {
                glyphs.fill(HomeColor.numeralFallback)
            }
        }
        .frame(width: Self.box.width, height: Self.box.height, alignment: .topLeading)
        .shadow(color: Color(hex: 0x280C02).opacity(0.42), radius: 12, y: 16)
        .accessibilityHidden(true)
    }

    private func art(_ design: StampDesign, dx: Double, dy: Double) -> some View {
        StampArtworkView(spec: design.artwork, seedKey: design.id)
            .frame(width: 284, height: 352)
            .offset(x: (Self.box.width - 284) / 2 + dx, y: -18 + dy)
            .frame(width: Self.box.width, height: Self.box.height, alignment: .topLeading)
    }
}
