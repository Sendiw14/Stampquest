import SwiftUI

/// The printed decoration of the passport page: guilloche rings, the spine shade, the dashed inner frame. Drawn once
/// and flattened, so scrolling and picking never redraw it. Purely decorative.
struct PassportPageDecor: View {
    static let ringRadii = stride(from: CGFloat(24), through: 230, by: 8)
    private static let spineWidth: CGFloat = 22
    private static let frameInset: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let page = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: PassportPageMetrics.corner)
            context.clip(to: page)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for radius in Self.ringRadii {
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                               with: .color(OnbColor.passportRings), lineWidth: 1)
            }
            context.fill(Path(CGRect(x: 0, y: 0, width: Self.spineWidth, height: size.height)),
                         with: .linearGradient(Gradient(colors: [OnbColor.passportSpine, OnbColor.passportSpine.opacity(0)]),
                                               startPoint: .zero, endPoint: CGPoint(x: Self.spineWidth, y: 0)))
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: Self.frameInset, dy: Self.frameInset)
            context.stroke(Path(roundedRect: frame, cornerRadius: 12), with: .color(OnbColor.passportDash),
                           style: StrokeStyle(lineWidth: 1.2, dash: [2, 4]))
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}
