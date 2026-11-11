import SwiftUI

/// A 120 x 160 unit stamp (aspect 3:4): perforated border, art panel, vignette, grain, hairline, label and number.
/// Decorative unless the caller wraps it in a button and supplies the label.
struct StampView: View {
    let destination: StampDestination
    let width: CGFloat
    /// 0 to 1 sweeps a soft-light sheen across the stamp. Nil draws none.
    var sheenProgress: CGFloat?
    /// The render cache turns this off so it caches the bare stamp.
    var showsShadow = true

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let grain = GrainNoise.image
        let destination = destination
        let sheen = sheenProgress
        stamp(grain: grain, destination: destination, sheen: sheen)
            .overlay {
                if showsShadow, scheme == .dark {
                    HolePunchedStampShape().stroke(Color.white.opacity(0.55), lineWidth: 0.6)
                }
            }
            .modifier(OptionalStampShadow(isOn: showsShadow))
            .accessibilityHidden(true)
    }

    private func stamp(grain: CGImage?, destination: StampDestination, sheen: CGFloat?) -> some View {
        Canvas { ctx, size in
            StampRenderer.draw(destination, in: &ctx, size: size, grain: grain, sheen: sheen)
        }
        .frame(width: width, height: width * HolePunchedStampShape.unitSize.height / HolePunchedStampShape.unitSize.width)
    }
}

private struct OptionalStampShadow: ViewModifier {
    let isOn: Bool
    func body(content: Content) -> some View {
        if isOn { content.obStampShadow() } else { content }
    }
}

nonisolated enum StampRenderer {
    private static let labelFont = Font.custom(OBFontName.newsreaderSemiBold, fixedSize: 9)
    private static let measure = CGSize(width: 1000, height: 1000)
    private static let numberFont = Font.custom(OBFontName.newsreaderItalic, fixedSize: 8.5)

    static func draw(_ destination: StampDestination, in ctx: inout GraphicsContext, size: CGSize, grain: CGImage?, sheen: CGFloat?) {
        let scale = size.width / HolePunchedStampShape.unitSize.width
        ctx.scaleBy(x: scale, y: scale)

        ctx.fill(HolePunchedStampShape.unitPath, with: .color(StampArt.borderColor(destination.style)))

        var panel = ctx
        panel.translateBy(x: 9, y: 9)
        let panelShape = Path(roundedRect: StampArt.panelRect, cornerRadius: OBRadius.stampPanel)
        panel.clip(to: panelShape)
        StampArt.draw(destination.style, in: &panel)
        drawVignette(&panel)
        if let grain {
            var g = panel
            g.blendMode = .multiply
            g.opacity = 0.16
            g.draw(g.resolve(Image(decorative: grain, scale: 1)), in: StampArt.panelRect)
        }
        panel.stroke(Path(roundedRect: StampArt.panelRect.insetBy(dx: 0.3, dy: 0.3), cornerRadius: OBRadius.stampPanel),
                     with: .color(StampArt.ink(OBColor.stampLabelInk, 0.5)), lineWidth: 0.6)

        let name = ctx.resolve(Text(destination.label).font(labelFont).tracking(0.8).foregroundColor(StampArt.ink(OBColor.stampLabelInk)))
        ctx.draw(name, at: CGPoint(x: 11, y: 148 - name.firstBaseline(in: Self.measure)), anchor: .topLeading)
        let number = ctx.resolve(Text(destination.numberLabel).font(numberFont).foregroundColor(StampArt.ink(OBColor.stampNumberInk)))
        ctx.draw(number, at: CGPoint(x: 109, y: 148 - number.firstBaseline(in: Self.measure)), anchor: .topTrailing)

        if let sheen { drawSheen(&ctx, progress: sheen) }
    }

    /// Radial vignette: transparent until 55%, black at 22% on the edge. CSS "farthest-corner ellipse" at (50%, 46%).
    private static func drawVignette(_ panel: inout GraphicsContext) {
        let center = CGPoint(x: 51, y: StampArt.panel.height * 0.46)
        let farX = 51.0, farY = max(center.y, StampArt.panel.height - center.y)
        let ry = farY * 2.0.squareRoot(), rx = farX * 2.0.squareRoot()
        var v = panel
        v.translateBy(x: center.x, y: center.y)
        v.scaleBy(x: rx / ry, y: 1)
        let gradient = Gradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.55),
                                        .init(color: .black.opacity(0.22), location: 1)])
        v.fill(Path(CGRect(x: -200, y: -200, width: 400, height: 400)),
               with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: ry))
    }

    /// Soft-light white band, 46 units wide, sweeping left to right across the stamp outline.
    private static func drawSheen(_ ctx: inout GraphicsContext, progress: CGFloat) {
        let bandWidth: CGFloat = 46
        let x = -bandWidth + (HolePunchedStampShape.unitSize.width + bandWidth) * progress
        var c = ctx
        c.clip(to: HolePunchedStampShape.unitPath)
        c.blendMode = .softLight
        let gradient = Gradient(stops: [.init(color: .white.opacity(0), location: 0), .init(color: .white.opacity(0.9), location: 0.5),
                                        .init(color: .white.opacity(0), location: 1)])
        c.fill(Path(CGRect(x: x, y: 0, width: bandWidth, height: 160)),
               with: .linearGradient(gradient, startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + bandWidth, y: 0)))
    }
}
