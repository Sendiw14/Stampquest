import SwiftUI

/// The cancellation mark pressed on a stamp: rings, text on the top and bottom arcs and an 8-point star. Drawn on the
/// style's own canvas and scaled to `size`; the caller rotates it.
extension StampPostmark {
    /// How far a postmark sits from the stamp's bottom-right corner so its ring clears the "No. 01" label: 10 pt right and 10 pt up. First stamp,
    /// Collected vs Verified and Passport ready all apply it, so the placement is the same on the three screens.
    static let labelClearance = CGSize(width: 10, height: -10)
}

struct StampPostmark: View {
    struct Style {
        struct Ring {
            let radius: CGFloat
            let width: CGFloat
        }

        let canvas: CGFloat
        let rings: [Ring]
        let topRadius: CGFloat
        let topFont: CGFloat
        let topTracking: CGFloat
        let bottomRadius: CGFloat
        let bottomFont: CGFloat
        let bottomTracking: CGFloat
        let starScale: CGFloat
        /// Ink multiplies into the paper in light mode instead of sitting on top.
        let multipliesInLight: Bool

        /// Welcome: the city and today's date on a 98 unit canvas.
        static let welcome = Style(canvas: 98, rings: [Ring(radius: 46.5, width: 2.2), Ring(radius: 42, width: 1)],
                                   topRadius: 28, topFont: 11, topTracking: 3, bottomRadius: 37, bottomFont: 8, bottomTracking: 1.4,
                                   starScale: 0.62, multipliesInLight: false)
        /// Verification: the long word "COLLECTED" on the top arc, so smaller and tighter than the Welcome city.
        static let collected = Style(canvas: 98, rings: welcome.rings, topRadius: 29, topFont: 9, topTracking: 1.5, bottomRadius: 37,
                                     bottomFont: 8, bottomTracking: 1.4, starScale: 0.62, multipliesInLight: false)
        /// Interests: the "PICKED" stamp, three rings on a 54 unit canvas (2.1, 1.1 and 0.9 pt at 54 pt).
        static let picked = Style(canvas: 54, rings: [Ring(radius: 25.5, width: 2.1), Ring(radius: 22.5, width: 1.1),
                                                      Ring(radius: 11, width: 0.9)],
                                  topRadius: 14, topFont: 5.4, topTracking: 1.2, bottomRadius: 20, bottomFont: 4.2, bottomTracking: 0.7,
                                  starScale: 0.3, multipliesInLight: true)
    }

    let top: String
    let bottom: String
    let style: Style
    let size: CGFloat
    let ink: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let top = top.uppercased(), bottom = bottom.uppercased()
        Canvas { context, canvas in
            let scale = canvas.width / style.canvas
            context.scaleBy(x: scale, y: scale)
            let center = CGPoint(x: style.canvas / 2, y: style.canvas / 2)
            for ring in style.rings {
                context.stroke(Path(ellipseIn: CGRect(x: center.x - ring.radius, y: center.y - ring.radius, width: ring.radius * 2,
                                                      height: ring.radius * 2)),
                               with: .color(ink), lineWidth: ring.width)
            }
            ArcText.draw(top, in: &context, center: center, radius: style.topRadius, tracking: style.topTracking, placement: .top,
                         font: .system(size: style.topFont, weight: .heavy), color: ink)
            ArcText.draw(bottom, in: &context, center: center, radius: style.bottomRadius, tracking: style.bottomTracking,
                         placement: .bottom, font: .system(size: style.bottomFont, weight: .bold), color: ink)
            var star = context
            star.translateBy(x: center.x, y: center.y)
            star.scaleBy(x: style.starScale, y: style.starScale)
            star.fill(StarShape.unitPath, with: .color(ink))
        }
        .frame(width: size, height: size)
        .blendMode(multiplies ? .multiply : .normal)
        .accessibilityHidden(true)
    }

    private var multiplies: Bool { scheme == .light && style.multipliesInLight }
}
