import SwiftUI

/// A disc whose edge has 28 scallops: radius 44.6 + 2 cos(28 theta) on a 100 unit canvas.
nonisolated struct ScallopedCircle: Shape {
    static let scallopCount = 28
    private static let steps = 560

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for step in 0...Self.steps {
            let angle = 2 * .pi * Double(step) / Double(Self.steps)
            let radius = (44.6 + 2.0 * cos(Double(Self.scallopCount) * angle)) * scale
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The gold "VERIFIED" seal: a scalloped disc, two rings, text on arcs and a map pin, on a 100 unit canvas. It is
/// illustrative where it is used for a preview and decorative to VoiceOver; the caller labels the group.
struct GoldSeal: View {
    /// The date printed on the bottom arc, already formatted and upper-case.
    let date: String
    var size: CGFloat = 100

    private static let gradient = Gradient(stops: [
        .init(color: StampArt.ink(0xFDF1C6), location: 0), .init(color: StampArt.ink(0xEBC768), location: 0.32),
        .init(color: StampArt.ink(0xC99432), location: 0.68), .init(color: StampArt.ink(0x8A5A12), location: 1),
    ])
    private static let highlight = StampArt.ink(0xFFF3C4)

    /// Map pin about the origin: a teardrop with a round hole.
    private static let pinPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 6.5))
        p.addCurve(to: CGPoint(x: -4.4, y: -2.6), control1: CGPoint(x: -1.2, y: 4.2), control2: CGPoint(x: -4.4, y: 1.2))
        p.addArc(center: CGPoint(x: 0, y: -2.6), radius: 4.4, startAngle: .radians(.pi), endAngle: .radians(0), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: 6.5), control1: CGPoint(x: 4.4, y: 1.2), control2: CGPoint(x: 1.2, y: 4.2))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: -1.7, y: -4.3, width: 3.4, height: 3.4))
        return p
    }()

    var body: some View {
        Canvas { context, canvas in
            let scale = canvas.width / 100
            context.translateBy(x: canvas.width / 2, y: canvas.height / 2)
            context.scaleBy(x: scale, y: scale)
            let box = CGRect(x: -50, y: -50, width: 100, height: 100)
            context.fill(ScallopedCircle().path(in: box),
                         with: .radialGradient(Self.gradient, center: CGPoint(x: -16, y: -22), startRadius: 0, endRadius: 95))
            ring(&context, radius: 38, width: 1.1, color: Self.highlight.opacity(0.75), offset: CGSize(width: -0.5, height: -0.5))
            ring(&context, radius: 38, width: 1.1, color: OnbColor.sealRingShadow.opacity(0.5), offset: CGSize(width: 0.6, height: 0.7))
            ring(&context, radius: 20.5, width: 0.9, color: OnbColor.sealRingShadow.opacity(0.45), offset: .zero)
            ArcText.draw("VERIFIED", in: &context, center: .zero, radius: 25.5, tracking: 1.9, placement: .top,
                         font: .system(size: 7.6, weight: .heavy), color: OnbColor.sealInk)
            ArcText.draw(date, in: &context, center: .zero, radius: 31.5, tracking: 1.1, placement: .bottom,
                         font: .system(size: 5.2, weight: .bold), color: OnbColor.sealInk)
            var pin = context
            pin.translateBy(x: 0, y: -1)
            pin.scaleBy(x: 0.82, y: 0.82)
            pin.fill(Self.pinPath, with: .color(OnbColor.sealInk), style: FillStyle(eoFill: true))
            var arc = Path()
            arc.addArc(center: .zero, radius: 38, startAngle: .degrees(201.25), endAngle: .degrees(248.75), clockwise: false)
            context.stroke(arc, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: size, height: size)
        .shadow(color: Color(.sRGB, red: 70 / 255, green: 42 / 255, blue: 0, opacity: 0.45), radius: 4, y: 6)
        .accessibilityHidden(true)
    }

    private func ring(_ context: inout GraphicsContext, radius: CGFloat, width: CGFloat, color: Color, offset: CGSize) {
        let rect = CGRect(x: -radius + offset.width, y: -radius + offset.height, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: width)
    }
}
