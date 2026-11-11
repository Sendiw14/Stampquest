import SwiftUI

/// Original tile illustrations, ported 1:1 from the design (145 x 72 units, scaled to fill and clipped).
struct InterestArt: View {
    let interest: Interest

    nonisolated static let artSize = CGSize(width: 145, height: 72)

    var body: some View {
        Canvas { ctx, size in
            let scale = max(size.width / Self.artSize.width, size.height / Self.artSize.height)
            ctx.translateBy(x: (size.width - Self.artSize.width * scale) / 2, y: (size.height - Self.artSize.height * scale) / 2)
            ctx.scaleBy(x: scale, y: scale)
            InterestArtDrawing.draw(interest, in: &ctx)
        }
        .accessibilityHidden(true)
    }
}

nonisolated enum InterestArtDrawing {
    private static var bounds: CGRect { CGRect(origin: .zero, size: InterestArt.artSize) }

    static func draw(_ interest: Interest, in ctx: inout GraphicsContext) {
        switch interest {
        case .cities: cities(&ctx)
        case .coasts: coasts(&ctx)
        case .mountains: mountains(&ctx)
        case .food: food(&ctx)
        case .history: history(&ctx)
        case .hiddenGems: hiddenGems(&ctx)
        }
    }

    private static func ink(_ hex: UInt32, _ alpha: Double = 1) -> Color { StampArt.ink(hex, alpha) }

    private static func sky(_ ctx: inout GraphicsContext, _ stops: [(UInt32, CGFloat)]) {
        ctx.fill(Path(bounds), with: .linearGradient(Gradient(stops: stops.map { .init(color: ink($0.0), location: $0.1) }),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: 72)))
    }

    private static func fill(_ ctx: inout GraphicsContext, _ path: Path, _ hex: UInt32, _ alpha: Double = 1) {
        ctx.fill(path, with: .color(ink(hex, alpha)))
    }

    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(CGRect(x: x, y: y, width: w, height: h)) }

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    private static func cities(_ ctx: inout GraphicsContext) {
        sky(&ctx, [(0xF3C6A5, 0), (0xEFB398, 0.6), (0xE99C88, 1)])
        fill(&ctx, circle(106, 26, 11), 0xFFF1D8)
        fill(&ctx, SVGPath.path("M0 72 V46 H12 V34 H24 V44 H32 V24 H44 V44 H52 V38 H66 V22 H76 V38 H88 V42 H100 V30 H114 V44 H124 V36 H136 V46 H145 V72 Z"), 0x2C3441)
        fill(&ctx, SVGPath.path("M69 22 L71 6 L73 22 Z"), 0x2C3441)
        for w in [(35, 30), (35, 38), (69, 28), (69, 35), (103, 35), (107, 40), (15, 40)] as [(CGFloat, CGFloat)] {
            fill(&ctx, rect(w.0, w.1, 2.4, 3.4), 0xF3C6A5, 0.85)
        }
    }

    private static func coasts(_ ctx: inout GraphicsContext) {
        sky(&ctx, [(0x8CC3E8, 0), (0xE2F0F8, 1)])
        fill(&ctx, circle(108, 26, 10), 0xFFF3D6)
        fill(&ctx, rect(0, 40, 145, 32), 0x2F78AE)
        fill(&ctx, rect(0, 40, 145, 7), 0x4A92C6, 0.7)
        fill(&ctx, SVGPath.path("M52 40 V18 L68 37 Z"), 0xFFFFFF)
        fill(&ctx, SVGPath.path("M50 40 H70 L66 46 H54 Z"), 0xC85A3C)
        let waves = SVGPath.path("M8 52 q6 -4 12 0 t12 0 t12 0 M88 49 q6 -4 12 0 t12 0 t12 0 M30 60 q6 -4 12 0 t12 0")
        ctx.stroke(waves, with: .color(ink(0xFFFFFF, 0.6)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        fill(&ctx, SVGPath.path("M0 66 C30 60 70 64 145 60 V72 H0 Z"), 0xEAD2B2)
    }

    private static func mountains(_ ctx: inout GraphicsContext) {
        sky(&ctx, [(0xC9DFEC, 0), (0xF6EFE0, 1)])
        fill(&ctx, circle(26, 18, 8), 0xFFF6DE)
        fill(&ctx, SVGPath.path("M28 62 L66 14 L104 62 Z"), 0x7F9DB3)
        fill(&ctx, SVGPath.path("M66 14 L75 26 L70 24 L66 30 L61 24 L57 26 Z"), 0xFFFFFF)
        fill(&ctx, SVGPath.path("M80 62 L112 26 L145 62 Z"), 0x5E7F98)
        fill(&ctx, SVGPath.path("M112 26 L119 35 L114 33 L112 37 L108 33 L105 35 Z"), 0xFFFFFF)
        fill(&ctx, SVGPath.path("M0 72 V56 C25 48 45 52 70 56 C95 60 120 50 145 54 V72 Z"), 0x3F5F4E)
        fill(&ctx, SVGPath.path("M18 58 l5 -13 l5 13 Z M26 60 l4 -10 l4 10 Z M112 58 l5 -13 l5 13 Z"), 0x2E4A3A)
    }

    private static func food(_ ctx: inout GraphicsContext) {
        sky(&ctx, [(0xF6D9A8, 0), (0xE9A870, 1)])
        fill(&ctx, SVGPath.path("M38 38 H107 C107 56 92 66 72.5 66 C53 66 38 56 38 38 Z"), 0xC4553B)
        fill(&ctx, Path(ellipseIn: CGRect(x: 72.5 - 34.5, y: 38 - 6, width: 69, height: 12)), 0xE9C99A)
        ctx.stroke(SVGPath.path("M50 38 q6 -5 12 0 t12 0 t12 0 t12 0"), with: .color(ink(0xF7E3B0)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
        ctx.stroke(SVGPath.path("M60 28 q4 -5 0 -9 q-4 -5 0 -9 M80 28 q4 -5 0 -9 q-4 -5 0 -9"), with: .color(ink(0xFFFFFF, 0.75)),
                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        ctx.stroke(SVGPath.path("M98 8 L124 34 M104 6 L128 30"), with: .color(ink(0x6B3E2A)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private static func history(_ ctx: inout GraphicsContext) {
        sky(&ctx, [(0xBFD6D3, 0), (0xEFE8D6, 1)])
        fill(&ctx, SVGPath.path("M30 24 L72.5 8 L115 24 Z"), 0xE9DFC8)
        fill(&ctx, rect(30, 24, 85, 5), 0xD8CBB0)
        for x in [35, 51, 69, 87, 103] as [CGFloat] { fill(&ctx, rect(x, 29, 7, 28), 0xF3ECDA) }
        for x in [39, 55, 73, 91, 107] as [CGFloat] { fill(&ctx, rect(x, 29, 3, 28), 0xD8CBB0, 0.7) }
        fill(&ctx, rect(28, 57, 89, 4), 0xD8CBB0)
        fill(&ctx, rect(23, 61, 99, 5), 0xC9BB9C)
        fill(&ctx, rect(0, 66, 145, 6), 0x8FA58B)
    }

    private static func hiddenGems(_ ctx: inout GraphicsContext) {
        sky(&ctx, [(0x86AE90, 0), (0x4A6E55, 1)])
        for s in [(16, 30, 12), (34, 22, 9), (128, 52, 13), (104, 60, 8)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, circle(s.0, s.1, s.2), 0x3F6249)
        }
        ctx.stroke(SVGPath.path("M14 62 C40 66 44 46 70 48 C96 50 98 34 120 32"), with: .color(ink(0xF4DFA2)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 5]))
        var star = ctx
        star.translateBy(x: 122, y: 28)
        star.scaleBy(x: 0.8, y: 0.8)
        star.fill(StarShape.unitPath, with: .color(ink(0xF4DFA2)))
    }
}
