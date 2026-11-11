import SwiftUI

/// A passport cover drawn in the 222 x 304 design space: leather with grain, spine and stitching, a foil frame and
/// emblem, the lettering and the holder's name. The leather and foil are cached as one bitmap; the gloss and the sheen,
/// which move, are drawn over it.
struct PassportCover: View {
    let style: CoverStyle
    let holderName: String
    var showsPageBlock = false
    var width: CGFloat = CoverMetrics.heroWidth
    /// Horizontal shift of the gloss band in points, from device tilt.
    var glossShift: CGFloat = 0
    /// Left edge of the sheen band in design units while it travels; nil when it rests.
    var sheenX: Double?

    private static let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    private static let foil = Gradient(stops: [
        .init(color: StampArt.ink(0xF8E4A8), location: 0), .init(color: StampArt.ink(0xDBB25C), location: 0.35),
        .init(color: StampArt.ink(0xF3D98F), location: 0.6), .init(color: StampArt.ink(0xC79B47), location: 1),
    ])

    private var unit: CGFloat { CoverMetrics.unit(forWidth: width) }

    var body: some View {
        let size = CoverMetrics.designSize
        ZStack(alignment: .topLeading) {
            if showsPageBlock { pageBlock }
            ZStack(alignment: .topLeading) {
                leather
                gloss
                sheen
            }
            .frame(width: size.width, height: size.height)
            .clipShape(Self.shape)
        }
        .frame(width: size.width + (showsPageBlock ? CoverMetrics.pageBlockExtent.width : 0),
               height: size.height + (showsPageBlock ? CoverMetrics.pageBlockExtent.height : 0), alignment: .topLeading)
        .scaleEffect(unit, anchor: .topLeading)
        .frame(width: CoverMetrics.groupSize(width: width, showsPageBlock: showsPageBlock).width,
               height: CoverMetrics.groupSize(width: width, showsPageBlock: showsPageBlock).height, alignment: .topLeading)
    }

    // MARK: Layers

    private var pageBlock: some View {
        let size = CoverMetrics.designSize
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(StampArt.ink(0xE9DFC9))
                .frame(width: 224, height: size.height).offset(x: 8, y: 6)
            Path { path in
                for index in 0..<4 {
                    let x = 223 + 1.4 * CGFloat(index)
                    path.move(to: CGPoint(x: x, y: 14))
                    path.addLine(to: CGPoint(x: x, y: size.height - 4))
                }
            }
            .stroke(StampArt.ink(0xCDBF9F), lineWidth: 0.8)
        }
    }

    private var leather: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, canvas in
                draw(&context, size: canvas)
            }
            if let grain = GrainNoise.image {
                Image(decorative: grain, scale: 1).resizable(resizingMode: .tile).opacity(0.24).blendMode(.multiply)
            }
        }
        .drawingGroup()
    }

    /// The soft gloss over the whole cover and the diagonal light band that follows the tilt.
    private var gloss: some View {
        let size = CoverMetrics.designSize
        return ZStack(alignment: .topLeading) {
            LinearGradient(stops: [.init(color: .white.opacity(0.24), location: 0), .init(color: .white.opacity(0), location: 0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.18), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 46, height: size.height + 80)
                .rotationEffect(.degrees(14))
                .offset(x: 112 + glossShift / unit, y: -40)
                .opacity(0.7)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var sheen: some View {
        if let sheenX {
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.42), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 56, height: CoverMetrics.designSize.height + 60)
                .rotationEffect(.degrees(14))
                .offset(x: sheenX, y: -30)
                .frame(width: CoverMetrics.designSize.width, height: CoverMetrics.designSize.height, alignment: .topLeading)
                .clipped()
                .allowsHitTesting(false)
        }
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let leather = style.leather
        let deep = StampArt.ink(leather.deep)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(style.gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        context.fill(Path(CGRect(x: 0, y: 0, width: 17, height: size.height)), with: .color(deep.opacity(0.30)))
        context.fill(Path(CGRect(x: 16.2, y: 0, width: 1.6, height: size.height)), with: .color(.white.opacity(0.16)))
        var stitch = Path()
        stitch.move(to: CGPoint(x: 27, y: 12))
        stitch.addLine(to: CGPoint(x: 27, y: size.height - 12))
        context.stroke(stitch, with: .color(.white.opacity(0.30)), style: StrokeStyle(lineWidth: 1.3, dash: [4, 5]))
        drawFoil(&context, size: size, deep: deep)
    }

    private func drawFoil(_ context: inout GraphicsContext, size: CGSize, deep: Color) {
        let gold = GraphicsContext.Shading.linearGradient(Self.foil, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
        for pass in 0..<2 {
            var layer = context
            let shading: GraphicsContext.Shading
            if pass == 0 { layer.translateBy(x: 0, y: 1.1); shading = .color(deep.opacity(0.6)) } else { shading = gold }
            foilShapes(&layer, size: size, shading: shading)
        }
    }

    private func foilShapes(_ context: inout GraphicsContext, size: CGSize, shading: GraphicsContext.Shading) {
        context.stroke(Path(roundedRect: CGRect(x: 40, y: 24, width: 164, height: 256), cornerRadius: 3), with: shading, lineWidth: 1.5)
        context.stroke(Path(roundedRect: CGRect(x: 46, y: 30, width: 152, height: 244), cornerRadius: 2), with: shading, lineWidth: 0.8)
        let center = CGPoint(x: 120, y: size.height * 0.44)
        context.stroke(Path(roundedRect: CGRect(x: center.x - 33, y: center.y - 33, width: 66, height: 66), cornerRadius: 2), with: shading,
                       style: StrokeStyle(lineWidth: 3.2, lineCap: .round, dash: [0.1, 5.4]))
        context.stroke(Path(roundedRect: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52), cornerRadius: 1), with: shading, lineWidth: 1)
        var star = context
        star.translateBy(x: center.x, y: center.y)
        star.scaleBy(x: 1.4, y: 1.4)
        star.fill(StarShape.unitPath, with: shading)
        text("STAMPQUEST", at: CGPoint(x: 120, y: size.height * 0.19), size: 12.2, tracking: 3.4, serif: false, in: &context, shading: shading)
        text("PASSPORT", at: CGPoint(x: 120, y: size.height * 0.715), size: 12.6, tracking: 5.2, serif: false, in: &context, shading: shading)
        if !holderName.isEmpty {
            text(holderName, at: CGPoint(x: 120, y: size.height * 0.815), size: CoverMetrics.nameFontSize(characterCount: holderName.count),
                 tracking: 0.3, serif: true, in: &context, shading: shading)
        }
    }

    private func text(_ string: String, at point: CGPoint, size: CGFloat, tracking: CGFloat, serif: Bool, in context: inout GraphicsContext,
                      shading: GraphicsContext.Shading) {
        let font: Font = serif ? .system(size: size, weight: .medium, design: .serif).italic() : .system(size: size, weight: .bold)
        let resolved = context.resolve(Text(string).font(font).tracking(tracking))
        context.drawLayer { layer in
            layer.clip(to: Path(CGRect(x: 0, y: 0, width: CoverMetrics.designSize.width, height: CoverMetrics.designSize.height)))
            layer.fill(Path(CGRect(origin: .zero, size: CoverMetrics.designSize)), with: shading)
            layer.blendMode = .destinationIn
            layer.draw(resolved, at: point, anchor: .center)
        }
    }
}
